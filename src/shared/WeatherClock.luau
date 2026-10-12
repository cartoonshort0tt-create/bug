--!strict
-- The global weather clock. Weather is a pure function of (zone, time), so every
-- server computes the same weather with no shared state, and the forecast is just
-- this function evaluated for future windows. Pass workspace:GetServerTimeNow().
--
-- Day/night: windows alternate. Even windows are day (the first DawnSeconds are
-- dawn), odd windows are night. One 20-minute day = one day window + one night window.

local Weather = require(script.Parent.Config.Weather)
local Zones = require(script.Parent.Config.Zones)

export type Phase = "dawn" | "day" | "night"

export type State = {
	zone: string,
	window: number,
	phase: Phase,
	weather: string,
	mutation: Weather.Mutation?,
	rainbow: boolean,
	eclipse: boolean,
	windowEndsAt: number,
}

local WeatherClock = {}

local TWO32 = 4294967296

-- 32-bit multiply that stays exact in doubles.
local function mul32(a: number, b: number): number
	local aLo = a % 65536
	local aHi = (a - aLo) / 65536
	return ((aHi * b) % 65536 * 65536 + aLo * b) % TWO32
end

-- murmur3 finalizer: spreads every input bit over the output.
local function fmix32(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end

-- Deterministic number in [0, 1) from three integers. Identical on every server.
function WeatherClock.hash01(a: number, b: number, c: number): number
	local h = fmix32(Weather.Seed % TWO32)
	h = fmix32(bit32.bxor(h, a % TWO32))
	h = fmix32((bit32.bxor(h, b % TWO32) + 0x9E3779B9) % TWO32)
	h = fmix32(bit32.bxor(h, c % TWO32))
	return h / TWO32
end

function WeatherClock.windowAt(t: number): number
	return math.floor(t / Weather.WindowSeconds)
end

function WeatherClock.isNightWindow(window: number): boolean
	return window % 2 == 1
end

function WeatherClock.isEclipse(t: number): boolean
	return t % Weather.Eclipse.every < Weather.Eclipse.duration
end

function WeatherClock.phaseAt(t: number): Phase
	if WeatherClock.isEclipse(t) then
		return "night"
	end
	local window = WeatherClock.windowAt(t)
	if WeatherClock.isNightWindow(window) then
		return "night"
	end
	if t - window * Weather.WindowSeconds < Weather.DawnSeconds then
		return "dawn"
	end
	return "day"
end

-- The weather entry rolled for a zone in a window.
function WeatherClock.entryIn(zoneId: string, window: number): Weather.Entry
	local tbl = Weather.Zones[zoneId]
	assert(tbl, "no weather table for zone " .. zoneId)
	local r = WeatherClock.hash01(Zones.IndexOf[zoneId], window, 1)
	local acc = 0
	local picked = tbl[#tbl]
	for _, entry in tbl do
		acc += entry.weight
		if r < acc then
			picked = entry
			break
		end
	end
	if picked.nightOnly and not WeatherClock.isNightWindow(window) then
		return tbl[1]
	end
	return picked
end

-- A Rainbow can open the window after a Thunderstorm, for its first `duration` seconds.
function WeatherClock.isRainbow(zoneId: string, t: number): boolean
	local window = WeatherClock.windowAt(t)
	if t - window * Weather.WindowSeconds >= Weather.Rainbow.duration then
		return false
	end
	if WeatherClock.entryIn(zoneId, window - 1).name ~= "Thunderstorm" then
		return false
	end
	return WeatherClock.hash01(Zones.IndexOf[zoneId], window, 2) < Weather.Rainbow.chanceAfterStorm
end

function WeatherClock.stateAt(zoneId: string, t: number): State
	local window = WeatherClock.windowAt(t)
	local entry = WeatherClock.entryIn(zoneId, window)
	local rainbow = WeatherClock.isRainbow(zoneId, t)
	local eclipse = WeatherClock.isEclipse(t)

	-- One weather mutation applies at a time; the rarest event wins.
	local mutation = entry.mutation
	if eclipse then
		mutation = Weather.Eclipse.mutation
	end
	if rainbow then
		mutation = Weather.Rainbow.mutation
	end

	return {
		zone = zoneId,
		window = window,
		phase = WeatherClock.phaseAt(t),
		weather = entry.name,
		mutation = mutation,
		rainbow = rainbow,
		eclipse = eclipse,
		windowEndsAt = (window + 1) * Weather.WindowSeconds,
	}
end

export type ForecastItem = { startsAt: number, weather: string, night: boolean }

-- The next `count` windows after the current one.
function WeatherClock.forecast(zoneId: string, t: number, count: number): { ForecastItem }
	local first = WeatherClock.windowAt(t) + 1
	local out: { ForecastItem } = {}
	for w = first, first + count - 1 do
		table.insert(out, {
			startsAt = w * Weather.WindowSeconds,
			weather = WeatherClock.entryIn(zoneId, w).name,
			night = WeatherClock.isNightWindow(w),
		})
	end
	return out
end

-- The next window (within `lookahead` windows) whose weather is not the zone's normal weather.
function WeatherClock.nextSpecial(zoneId: string, t: number, lookahead: number): ForecastItem?
	local normal = Weather.Zones[zoneId][1].name
	for _, item in WeatherClock.forecast(zoneId, t, lookahead) do
		if item.weather ~= normal then
			return item
		end
	end
	return nil
end

return WeatherClock
