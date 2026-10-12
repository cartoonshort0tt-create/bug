--!strict
-- The 8 zones in progression order. Gate prices come from the v1.2 economy:
-- each gate costs 25–420 minutes of play in the zone before it.
-- `released` controls whether the gate can be bought yet (post-launch zones stay locked).
-- `area` is the spawn rectangle for zones that exist in the world (prototype: Meadow only).

export type Area = { x: number, z: number, sizeX: number, sizeZ: number, y: number }

export type Zone = {
	id: string,
	name: string,
	gatePrice: number,
	released: boolean,
	liveBugs: number,
	area: Area?,
}

local List: { Zone } = {
	{
		id = "Meadow",
		name = "Sunny Meadow",
		gatePrice = 0,
		released = true,
		liveBugs = 25,
		area = { x = 0, z = -10, sizeX = 340, sizeZ = 220, y = 3 },
	},
	{ id = "Forest", name = "Whispering Forest", gatePrice = 2_500, released = true, liveBugs = 28 },
	{ id = "Swamp", name = "Misty Swamp", gatePrice = 10_000, released = true, liveBugs = 28 },
	{ id = "Desert", name = "Desert Canyon", gatePrice = 50_000, released = true, liveBugs = 28 },
	{ id = "Caves", name = "Crystal Caves", gatePrice = 300_000, released = false, liveBugs = 30 },
	{ id = "Volcano", name = "Volcano Island", gatePrice = 1_500_000, released = false, liveBugs = 30 },
	{ id = "Peak", name = "Himalayan Peak", gatePrice = 7_000_000, released = false, liveBugs = 30 },
	{ id = "Sky", name = "Sky Kingdom", gatePrice = 30_000_000, released = false, liveBugs = 30 },
}

local ById: { [string]: Zone } = {}
local IndexOf: { [string]: number } = {}
for i, zone in List do
	ById[zone.id] = zone
	IndexOf[zone.id] = i
end

return {
	List = List,
	ById = ById,
	IndexOf = IndexOf,
}
