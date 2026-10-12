--!strict
-- Recomputes expected coins per catch for every zone from the configs and checks
-- the ×3 rule (each zone pays 2.7–3.3× the one before it). Runs on server start in
-- Studio and in tools/run_tests.py. Averages over day and night windows, each zone's
-- weather table and the after-storm Rainbow; base luck, no mutations or variants.

local Bugs = require(script.Parent.Config.Bugs)
local Weather = require(script.Parent.Config.Weather)
local Zones = require(script.Parent.Config.Zones)
local SpawnOdds = require(script.Parent.SpawnOdds)

export type ZoneResult = { zone: string, coinsPerCatch: number, ratio: number? }

local EconomyCheck = {}

EconomyCheck.MinRatio = 2.7
EconomyCheck.MaxRatio = 3.3

local function evFor(zoneId: string, cond: SpawnOdds.Conditions): number
	local ev = 0
	for _, row in SpawnOdds.table(zoneId, cond, 0) do
		ev += row.chance * row.bug.value
	end
	return ev
end

function EconomyCheck.coinsPerCatch(zoneId: string): number
	local tbl = Weather.Zones[zoneId]
	local dawnShare = Weather.DawnSeconds / Weather.WindowSeconds

	-- Share of time a Rainbow is active: P(previous window was a storm) × chance × duration share.
	local stormP = 0
	for _, entry in tbl do
		if entry.name == "Thunderstorm" then
			stormP += entry.weight
		end
	end
	local rainbowShare = stormP * Weather.Rainbow.chanceAfterStorm * (Weather.Rainbow.duration / Weather.WindowSeconds)

	local total = 0
	for _, night in { false, true } do
		for _, entry in tbl do
			local weatherName = entry.name
			if entry.nightOnly and not night then
				weatherName = tbl[1].name
			end
			local phases: { { phase: "dawn" | "day" | "night", share: number } } = if night
				then { { phase = "night", share = 1 } }
				else { { phase = "dawn", share = dawnShare }, { phase = "day", share = 1 - dawnShare } }
			for _, ph in phases do
				local base = 0.5 * entry.weight * ph.share
				local withRainbow = evFor(zoneId, { phase = ph.phase, weather = weatherName, rainbow = true })
				local without = evFor(zoneId, { phase = ph.phase, weather = weatherName, rainbow = false })
				total += base * (rainbowShare * withRainbow + (1 - rainbowShare) * without)
			end
		end
	end
	return total
end

function EconomyCheck.run(): ({ ZoneResult }, boolean)
	local results: { ZoneResult } = {}
	local ok = true
	local prev: number? = nil
	for _, zone in Zones.List do
		local ev = EconomyCheck.coinsPerCatch(zone.id)
		local ratio = if prev then ev / prev else nil
		if ratio and (ratio < EconomyCheck.MinRatio or ratio > EconomyCheck.MaxRatio) then
			ok = false
		end
		table.insert(results, { zone = zone.id, coinsPerCatch = ev, ratio = ratio })
		prev = ev
	end

	-- Every zone needs a Common that can spawn at any time and in any weather.
	for _, zone in Zones.List do
		local hasAlwaysCommon = false
		local zoneBugs: { Bugs.Bug } = Bugs.ByZone[zone.id] or {}
		for _, bug in zoneBugs do
			if bug.tier == "Common" and bug.time == "any" and bug.weather == nil then
				hasAlwaysCommon = true
			end
		end
		if not hasAlwaysCommon then
			ok = false
		end
	end

	return results, ok
end

function EconomyCheck.report(): string
	local results, ok = EconomyCheck.run()
	local lines = { "EconomyCheck: " .. (if ok then "OK" else "FAILED") }
	for _, r in results do
		local ratioText = if r.ratio then string.format("x%.2f", r.ratio) else "-"
		table.insert(lines, string.format("  %-8s %12.1f coins/catch  %s", r.zone, r.coinsPerCatch, ratioText))
	end
	return table.concat(lines, "\n")
end

return EconomyCheck
