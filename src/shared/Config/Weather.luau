--!strict
-- Weather tables per zone, rolled once per 10-minute window on a global clock.
-- The first entry of each zone is its "normal" weather. Night-only entries
-- fall back to the normal weather when rolled in a day window.

export type Mutation = { name: string, mult: number }

export type Entry = {
	name: string,
	weight: number,
	nightOnly: boolean?,
	mutation: Mutation?,
}

local DEWY = { name = "Dewy", mult = 1.5 }
local MISTY = { name = "Misty", mult = 1.5 }
local SCORCHED = { name = "Scorched", mult = 2 }
local GLOWING = { name = "Glowing", mult = 2 }
local DUSTY = { name = "Dusty", mult = 2.5 }
local FROZEN = { name = "Frozen", mult = 2.5 }
local ELECTRIC = { name = "Electric", mult = 3 }
local MOLTEN = { name = "Molten", mult = 3 }
local AURORAL = { name = "Auroral", mult = 4 }
local STARLIT = { name = "Starlit", mult = 4 }

local Zones: { [string]: { Entry } } = {
	Meadow = {
		{ name = "Sunny", weight = 0.7 },
		{ name = "Light rain", weight = 0.3, mutation = DEWY },
	},
	Forest = {
		{ name = "Clear", weight = 0.6 },
		{ name = "Fog", weight = 0.3, mutation = MISTY },
		{ name = "Rain", weight = 0.1, mutation = DEWY },
	},
	Swamp = {
		{ name = "Mist", weight = 0.5 },
		{ name = "Rain", weight = 0.35, mutation = DEWY },
		{ name = "Thunderstorm", weight = 0.15, mutation = ELECTRIC },
	},
	Desert = {
		{ name = "Clear", weight = 0.55 },
		{ name = "Heat wave", weight = 0.3, mutation = SCORCHED },
		{ name = "Sandstorm", weight = 0.15, mutation = DUSTY },
	},
	Caves = {
		{ name = "Calm", weight = 0.75 },
		{ name = "Glow surge", weight = 0.25, mutation = GLOWING },
	},
	Volcano = {
		{ name = "Smoky", weight = 0.75 },
		{ name = "Eruption", weight = 0.25, mutation = MOLTEN },
	},
	Peak = {
		{ name = "Clear", weight = 0.5 },
		{ name = "Snow", weight = 0.35, mutation = FROZEN },
		{ name = "Blizzard", weight = 0.15, mutation = FROZEN },
	},
	Sky = {
		{ name = "Clear", weight = 0.55 },
		{ name = "Thunderstorm", weight = 0.2, mutation = ELECTRIC },
		{ name = "Aurora", weight = 0.15, nightOnly = true, mutation = AURORAL },
		{ name = "Meteor shower", weight = 0.1, nightOnly = true, mutation = STARLIT },
	},
}

return {
	-- Change SEED only between seasons: it reshuffles every forecast.
	Seed = 20261012,
	WindowSeconds = 600, -- one weather roll per zone per window
	DawnSeconds = 120, -- the first 2 minutes of each day window
	MutationChance = 0.15, -- share of catches that get the active weather mutation

	-- After a Thunderstorm window, the next window may open with a Rainbow.
	Rainbow = {
		chanceAfterStorm = 0.25,
		duration = 300,
		mutation = { name = "Rainbow", mult = 10 } :: Mutation,
	},

	-- Scheduled for everyone: every 3 hours, 5 minutes of night with Moonlit catches.
	Eclipse = {
		every = 10_800,
		duration = 300,
		mutation = { name = "Moonlit", mult = 6 } :: Mutation,
	},

	Zones = Zones,
}
