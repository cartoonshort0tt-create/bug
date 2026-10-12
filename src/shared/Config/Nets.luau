--!strict
-- The 12 nets, bought in order. In each zone the nets cost about 0.6× that
-- zone's exit gate in total. Luck is a fraction (0.5 = +50%).
-- reach: studs from the player to the bug. speed: shortens the swing cooldown.
-- power: heavy bugs (e.g. Hercules Beetle) need a minimum Power.

export type Net = {
	id: string,
	name: string,
	zone: string,
	cost: number,
	reach: number,
	speed: number,
	power: number,
	luck: number,
}

local List: { Net } = {
	{ id = "Twig", name = "Twig Net", zone = "Meadow", cost = 0, reach = 6, speed = 1.0, power = 1, luck = 0 },
	{ id = "Cotton", name = "Cotton Net", zone = "Meadow", cost = 150, reach = 7, speed = 1.1, power = 2, luck = 0.02 },
	{ id = "Bamboo", name = "Bamboo Net", zone = "Forest", cost = 2_000, reach = 8, speed = 1.2, power = 3, luck = 0.04 },
	{ id = "Silk", name = "Silk Net", zone = "Forest", cost = 4_000, reach = 9, speed = 1.3, power = 6, luck = 0.06 },
	{ id = "Reed", name = "Reed Net", zone = "Swamp", cost = 10_000, reach = 10, speed = 1.45, power = 7, luck = 0.09 },
	{ id = "Storm", name = "Storm Net", zone = "Swamp", cost = 20_000, reach = 11, speed = 1.55, power = 8, luck = 0.12 },
	{ id = "Sandsteel", name = "Sandsteel Net", zone = "Desert", cost = 150_000, reach = 12, speed = 1.7, power = 10, luck = 0.15 },
	{ id = "Crystal", name = "Crystal Net", zone = "Caves", cost = 750_000, reach = 13, speed = 1.85, power = 12, luck = 0.2 },
	{ id = "Obsidian", name = "Obsidian Net", zone = "Volcano", cost = 3_500_000, reach = 14, speed = 2.0, power = 14, luck = 0.26 },
	{ id = "Summit", name = "Summit Net", zone = "Peak", cost = 15_000_000, reach = 15, speed = 2.15, power = 16, luck = 0.33 },
	{ id = "Cloud", name = "Cloud Net", zone = "Sky", cost = 40_000_000, reach = 16, speed = 2.3, power = 18, luck = 0.4 },
	{ id = "Aurora", name = "Aurora Net", zone = "Sky", cost = 120_000_000, reach = 18, speed = 2.5, power = 20, luck = 0.5 },
}

return {
	List = List,
}
