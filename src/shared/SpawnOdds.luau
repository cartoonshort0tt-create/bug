--!strict
-- Spawn odds for one zone at one moment. Shared by the server (to spawn bugs)
-- and the client (for the Bugdex "Odds" button), so both always agree.
--
-- 1. Keep only bugs whose time and weather conditions are met right now.
-- 2. Each tier present gets weight = baseWeight × (1 + luck) ^ exponent.
-- 3. Inside a tier, bugs share the weight evenly, ×boost when their boost weather is active.
-- 4. Normalize to 100%.

local Bugs = require(script.Parent.Config.Bugs)
local Rarity = require(script.Parent.Config.Rarity)

export type Conditions = {
	phase: "dawn" | "day" | "night",
	weather: string,
	rainbow: boolean,
}

export type Row = { bug: Bugs.Bug, chance: number }

local SpawnOdds = {}

local function timeOk(bugTime: string, phase: string): boolean
	if bugTime == "any" then
		return true
	elseif bugTime == "day" then
		return phase == "day" or phase == "dawn"
	else
		return bugTime == phase
	end
end

local function weatherOk(bugWeather: string?, cond: Conditions): boolean
	if bugWeather == nil then
		return true
	elseif bugWeather == "Rainbow" then
		return cond.rainbow
	else
		return bugWeather == cond.weather
	end
end

function SpawnOdds.isAvailable(bug: Bugs.Bug, cond: Conditions): boolean
	return timeOk(bug.time, cond.phase) and weatherOk(bug.weather, cond)
end

function SpawnOdds.table(zoneId: string, cond: Conditions, luck: number): { Row }
	luck = math.clamp(luck, 0, Rarity.MaxLuck)

	local byTier: { [string]: { Bugs.Bug } } = {}
	local zoneBugs: { Bugs.Bug } = Bugs.ByZone[zoneId] or {}
	for _, bug in zoneBugs do
		if SpawnOdds.isAvailable(bug, cond) then
			local list = byTier[bug.tier]
			if not list then
				list = {}
				byTier[bug.tier] = list
			end
			table.insert(list, bug)
		end
	end

	local rows: { Row } = {}
	local total = 0
	for _, tier in Rarity.Order do
		local list = byTier[tier]
		if list then
			local tierWeight = Rarity.BaseWeight[tier] * (1 + luck) ^ Rarity.LuckExponent[tier]
			local shares: { number } = {}
			local shareSum = 0
			for i, bug in list do
				local share = 1
				if bug.boost and bug.boost.weather == cond.weather then
					share = bug.boost.mult
				end
				shares[i] = share
				shareSum += share
			end
			for i, bug in list do
				local w = tierWeight * shares[i] / shareSum
				table.insert(rows, { bug = bug, chance = w })
				total += w
			end
		end
	end

	for _, row in rows do
		row.chance /= total
	end
	return rows
end

-- r is a uniform random number in [0, 1).
function SpawnOdds.pick(zoneId: string, cond: Conditions, luck: number, r: number): Bugs.Bug?
	local rows = SpawnOdds.table(zoneId, cond, luck)
	local acc = 0
	for _, row in rows do
		acc += row.chance
		if r < acc then
			return row.bug
		end
	end
	local last = rows[#rows]
	return if last then last.bug else nil
end

return SpawnOdds
