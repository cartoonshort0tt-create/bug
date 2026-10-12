-- Tests for the shared modules. Run with: python3 tools/run_tests.py
-- `Shared` and `require` are provided by the runner.

local Bugs = require(Shared.Config.Bugs)
local Nets = require(Shared.Config.Nets)
local Rarity = require(Shared.Config.Rarity)
local Weather = require(Shared.Config.Weather)
local Zones = require(Shared.Config.Zones)
local WeatherClock = require(Shared.WeatherClock)
local SpawnOdds = require(Shared.SpawnOdds)
local EconomyCheck = require(Shared.EconomyCheck)
local Format = require(Shared.Format)

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok    " .. name)
	else
		failed += 1
		print("  FAIL  " .. name .. "\n        " .. tostring(err))
	end
end

local function near(actual: number, expected: number, tolerance: number, what: string)
	if math.abs(actual - expected) > tolerance then
		error(string.format("%s: expected %.4f ± %.4f, got %.4f", what, expected, tolerance, actual), 2)
	end
end

print("Shared module tests")

test("48 bugs, 15 magical, 6 per zone", function()
	assert(#Bugs.List == 48, "bug count " .. #Bugs.List)
	local magic = 0
	for _, b in Bugs.List do
		if b.magic then
			magic += 1
		end
	end
	assert(magic == 15, "magic count " .. magic)
	for _, zone in Zones.List do
		assert(#Bugs.ByZone[zone.id] == 6, zone.id .. " has " .. #Bugs.ByZone[zone.id])
	end
end)

test("bug values follow zone base × rarity multiplier", function()
	for _, zone in Zones.List do
		local common = nil
		for _, b in Bugs.ByZone[zone.id] do
			if b.tier == "Common" then
				common = b.value
			end
		end
		assert(common, zone.id .. " has no Common")
		for _, b in Bugs.ByZone[zone.id] do
			local expected = common * Rarity.ValueMultiplier[b.tier]
			-- values are rounded to 2 significant figures, so allow 10%
			assert(math.abs(b.value / expected - 1) < 0.1, b.id .. " value off: " .. b.value .. " vs " .. expected)
		end
	end
end)

test("every bug weather condition exists in its zone (or is Rainbow)", function()
	for _, b in Bugs.List do
		for _, cond in { b.weather, if b.boost then b.boost.weather else nil } do
			if cond and cond ~= "Rainbow" then
				local found = false
				for _, entry in Weather.Zones[b.zone] do
					if entry.name == cond then
						found = true
					end
				end
				assert(found, b.id .. " needs weather '" .. cond .. "' which " .. b.zone .. " never rolls")
			end
		end
	end
end)

test("weather tables sum to 1", function()
	for zoneId, tbl in Weather.Zones do
		local sum = 0
		for _, e in tbl do
			sum += e.weight
		end
		near(sum, 1, 1e-9, zoneId)
	end
end)

test("nets are bought in order and get strictly better", function()
	for i = 2, #Nets.List do
		local a, b = Nets.List[i - 1], Nets.List[i]
		assert(b.cost > a.cost and b.reach >= a.reach and b.speed > a.speed and b.power > a.power, b.id)
	end
	-- Hercules Beetle needs Power 6, first reachable with the Silk Net in the Forest.
	assert(Nets.List[4].id == "Silk" and Nets.List[4].power == 6)
end)

test("weather clock is deterministic", function()
	for w = 2_900_000, 2_900_050 do
		assert(WeatherClock.entryIn("Swamp", w).name == WeatherClock.entryIn("Swamp", w).name)
	end
	local t = 1_760_000_123.4
	local a, b = WeatherClock.stateAt("Sky", t), WeatherClock.stateAt("Sky", t)
	assert(a.weather == b.weather and a.phase == b.phase and a.rainbow == b.rainbow)
end)

test("weather frequencies match the tables over 40,000 windows", function()
	for zoneId, tbl in Weather.Zones do
		local counts: { [string]: number } = {}
		local n = 40_000
		local start = 2_900_000
		for w = start, start + n - 1 do
			local name = WeatherClock.entryIn(zoneId, w).name
			counts[name] = (counts[name] or 0) + 1
		end
		for i, entry in tbl do
			local expected = entry.weight
			if entry.nightOnly then
				expected = entry.weight / 2 -- only rolls in night windows
			elseif i == 1 then
				for _, e in tbl do
					if e.nightOnly then
						expected += e.weight / 2 -- day windows fall back to normal
					end
				end
			end
			near((counts[entry.name] or 0) / n, expected, 0.012, zoneId .. " " .. entry.name)
		end
	end
end)

test("night-only weather never appears in day windows", function()
	for w = 2_900_000, 2_910_000, 2 do -- even = day
		local name = WeatherClock.entryIn("Sky", w).name
		assert(name ~= "Aurora" and name ~= "Meteor shower", "night-only weather in day window " .. w)
	end
end)

test("phases: dawn, day, night and eclipse", function()
	local W = Weather.WindowSeconds
	local dayStart = 2_900_000 * W + 1 -- window 2,900,000 is even (day); +1 s avoids the boundary
	-- avoid eclipse minutes when testing normal phases
	while WeatherClock.isEclipse(dayStart) or WeatherClock.isEclipse(dayStart + W + 10) do
		dayStart += 2 * W
	end
	assert(WeatherClock.phaseAt(dayStart + 10) == "dawn")
	assert(WeatherClock.phaseAt(dayStart + Weather.DawnSeconds + 10) == "day")
	assert(WeatherClock.phaseAt(dayStart + W + 10) == "night")
	local eclipseT = math.floor(dayStart / Weather.Eclipse.every + 1) * Weather.Eclipse.every + 5
	assert(WeatherClock.isEclipse(eclipseT) and WeatherClock.phaseAt(eclipseT) == "night")
	assert(WeatherClock.stateAt("Meadow", eclipseT).mutation.name == "Moonlit")
end)

test("Sky rainbow is active about 2.5% of the time", function()
	local W = Weather.WindowSeconds
	local hits, samples = 0, 0
	for w = 2_900_000, 2_960_000 do
		for offset = 30, 570, 60 do -- 10 evenly spaced samples per window
			samples += 1
			if WeatherClock.isRainbow("Sky", w * W + offset) then
				hits += 1
			end
		end
	end
	near(hits / samples, 0.2 * 0.25 * 0.5, 0.004, "rainbow share")
end)

test("spawn tables are never empty and sum to 1", function()
	for _, zone in Zones.List do
		for _, phase in { "dawn", "day", "night" } do
			for _, entry in Weather.Zones[zone.id] do
				for _, rainbow in { false, true } do
					for _, luck in { 0, 1, 4, 10 } do
						local rows = SpawnOdds.table(zone.id, { phase = phase :: any, weather = entry.name, rainbow = rainbow }, luck)
						assert(#rows > 0, zone.id .. " empty at " .. phase .. "/" .. entry.name)
						local sum = 0
						for _, r in rows do
							sum += r.chance
						end
						near(sum, 1, 1e-9, zone.id)
					end
				end
			end
		end
	end
end)

test("luck odds match the blueprint table at +400%", function()
	-- Caves with a night Glow surge has every tier available, one Legendary and one Mythic.
	local rows = SpawnOdds.table("Caves", { phase = "night", weather = "Glow surge", rainbow = false }, 4)
	local byTier: { [string]: number } = {}
	for _, r in rows do
		byTier[r.bug.tier] = (byTier[r.bug.tier] or 0) + r.chance
	end
	near(byTier.Common, 0.4256, 0.0005, "Common")
	near(byTier.Legendary, 0.0500, 0.0005, "Legendary")
	near(byTier.Mythic, 0.0049, 0.0001, "Mythic")
	-- luck above the cap is clamped
	local capped = SpawnOdds.table("Caves", { phase = "night", weather = "Glow surge", rainbow = false }, 99)
	near(capped[1].chance, rows[1].chance, 1e-12, "cap")
end)

test("boost weather triples a bug's share within its tier", function()
	local calm = SpawnOdds.table("Caves", { phase = "day", weather = "Calm", rainbow = false }, 0)
	local surge = SpawnOdds.table("Caves", { phase = "day", weather = "Glow surge", rainbow = false }, 0)
	local function share(rows, id)
		local epic, mine = 0, 0
		for _, r in rows do
			if r.bug.tier == "Epic" then
				epic += r.chance
				if r.bug.id == id then
					mine += r.chance
				end
			end
		end
		return mine / epic
	end
	near(share(calm, "BlueWeevil"), 0.5, 1e-9, "calm share")
	near(share(surge, "BlueWeevil"), 0.75, 1e-9, "surge share")
end)

test("economy: every zone pays 2.7-3.3x the previous one", function()
	local results, ok = EconomyCheck.run()
	print(EconomyCheck.report())
	assert(ok, "EconomyCheck failed")
	near(results[1].coinsPerCatch, 12, 0.6, "Meadow coins/catch")
end)

test("format helpers", function()
	assert(Format.commas(0) == "0")
	assert(Format.commas(999) == "999")
	assert(Format.commas(1000) == "1,000")
	assert(Format.commas(30000000) == "30,000,000")
	assert(Format.commas(-2500) == "-2,500")
	assert(Format.clock(125) == "2:05")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
