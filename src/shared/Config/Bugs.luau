--!strict
-- The 48 launch bugs (blueprint v1.2). Value = zone base × rarity multiplier,
-- which makes each zone pay ×3 the one before it. Tools: EconomyCheck verifies this.
--
-- time:    "any" | "day" (includes dawn) | "night" | "dawn"
-- weather: nil = any weather; a weather name from Config/Weather; or "Rainbow"
-- boost:   spawns ×mult more often (within its tier) during that weather

local Rarity = require(script.Parent.Rarity)

export type TimeOfDay = "any" | "day" | "night" | "dawn"

export type Bug = {
	id: string,
	name: string,
	zone: string,
	tier: Rarity.Tier,
	value: number,
	time: TimeOfDay,
	weather: string?,
	boost: { weather: string, mult: number }?,
	power: number?, -- minimum net Power needed to catch it
	firstCatchValue: number?, -- value the first time a player catches it
	magic: boolean,
	fact: string,
}

local function bug(
	zone: string,
	id: string,
	name: string,
	tier: Rarity.Tier,
	value: number,
	time: TimeOfDay,
	fact: string,
	extra: { [string]: any }?
): Bug
	local b: Bug = {
		id = id,
		name = name,
		zone = zone,
		tier = tier,
		value = value,
		time = time,
		magic = false,
		fact = fact,
	}
	if extra then
		b.weather = extra.weather
		b.boost = extra.boost
		b.power = extra.power
		b.firstCatchValue = extra.firstCatchValue
		b.magic = extra.magic == true
	end
	return b
end

local List: { Bug } = {
	-- Sunny Meadow
	bug("Meadow", "Ladybug", "Ladybug", "Common", 4, "any", "Can eat about 5,000 aphids in its lifetime."),
	bug("Meadow", "Grasshopper", "Grasshopper", "Common", 4, "any", "Can jump about 20 times its own body length."),
	bug("Meadow", "CabbageWhite", "Cabbage White Butterfly", "Common", 4, "day", "Butterflies taste with their feet."),
	bug("Meadow", "Honeybee", "Honeybee", "Rare", 15, "day", 'Does a "waggle dance" to tell other bees where flowers are.'),
	bug("Meadow", "Monarch", "Monarch Butterfly", "Epic", 58, "day", "Migrates up to about 4,800 km to Mexico."),
	bug("Meadow", "GoldenLadybug", "Golden Ladybug", "Legendary", 310, "any", "A magical good-luck charm of the meadow.", {
		magic = true,
		firstCatchValue = 900,
	}),

	-- Whispering Forest
	bug("Forest", "WalkingStick", "Walking Stick", "Common", 11, "any", "Hides by looking exactly like a twig."),
	bug("Forest", "Firefly", "Firefly", "Common", 11, "night", "Makes light with almost no heat."),
	bug("Forest", "StagBeetle", "Stag Beetle", "Rare", 43, "any", "Males use their huge jaws to wrestle, not to bite."),
	bug("Forest", "AtlasMoth", "Atlas Moth", "Epic", 160, "night", "Adults have no mouth and live only one to two weeks."),
	bug("Forest", "HerculesBeetle", "Hercules Beetle", "Legendary", 850, "any", "One of the strongest animals for its size.", {
		power = 6,
	}),
	bug("Forest", "GlowcapBeetle", "Glowcap Beetle", "Mythic", 6_400, "night", "Its shell glows like a forest mushroom.", {
		weather = "Fog",
		magic = true,
	}),

	-- Misty Swamp
	bug("Swamp", "Mosquito", "Mosquito", "Common", 39, "any", "Only female mosquitoes bite."),
	bug("Swamp", "WaterStrider", "Water Strider", "Common", 39, "day", "Walks on water using surface tension."),
	bug("Swamp", "DivingBeetle", "Diving Beetle", "Rare", 160, "any", "Carries an air bubble to breathe underwater.", {
		boost = { weather = "Rain", mult = 3 },
	}),
	bug("Swamp", "Dragonfly", "Dragonfly", "Rare", 160, "day", "Catches about 95% of the prey it hunts."),
	bug("Swamp", "PrayingMantis", "Praying Mantis", "Epic", 590, "any", "Can turn its head about 180 degrees."),
	bug("Swamp", "LilyDragon", "Lily Dragon", "Legendary", 3_100, "any", "A dragonfly that crackles with lightning.", {
		weather = "Thunderstorm",
		magic = true,
	}),

	-- Desert Canyon
	bug("Desert", "DesertLocust", "Desert Locust", "Common", 120, "any", "Swarms can contain billions of locusts."),
	bug("Desert", "DungBeetle", "Dung Beetle", "Rare", 460, "any", "Some find their way using the Milky Way."),
	bug("Desert", "Scorpion", "Scorpion", "Epic", 1_700, "night", "Glows blue-green under UV light. It is an arachnid, not an insect."),
	bug("Desert", "TarantulaHawk", "Tarantula Hawk", "Epic", 1_700, "day", "A huge wasp that hunts tarantulas.", {
		boost = { weather = "Heat wave", mult = 3 },
	}),
	bug("Desert", "GoldenScarab", "Golden Scarab", "Legendary", 9_300, "dawn", "Ancient Egyptians linked scarabs with the rising sun."),
	bug("Desert", "SandPhantom", "Sand Phantom", "Mythic", 70_000, "any", "Appears only inside a sandstorm.", {
		weather = "Sandstorm",
		magic = true,
	}),

	-- Crystal Caves
	bug("Caves", "CaveCricket", "Cave Cricket", "Common", 330, "any", "Uses extra-long antennae to feel its way in the dark."),
	bug("Caves", "Glowworm", "Glowworm", "Rare", 1_300, "any", "Some hang glowing sticky threads to catch prey."),
	bug("Caves", "BlindCaveBeetle", "Blind Cave Beetle", "Epic", 5_000, "any", "Some cave beetles have no eyes at all."),
	bug("Caves", "BlueWeevil", "Blue Weevil", "Epic", 5_000, "any", "Shiny blue-green weevils live in New Guinea forests.", {
		boost = { weather = "Glow surge", mult = 3 },
	}),
	bug("Caves", "CrystalMoth", "Crystal Moth", "Legendary", 26_000, "any", "Its wings are made of living crystal.", {
		weather = "Glow surge",
		magic = true,
	}),
	bug("Caves", "PrismBeetle", "Prism Beetle", "Mythic", 200_000, "night", "Splits light into a rainbow.", {
		weather = "Glow surge",
		magic = true,
	}),

	-- Volcano Island
	bug("Volcano", "FireAnt", "Fire Ant", "Common", 910, "any", "Can link bodies together to build rafts in floods."),
	bug("Volcano", "Cicada", "Cicada", "Rare", 3_600, "day", "Some cicadas live 17 years underground."),
	bug("Volcano", "BombardierBeetle", "Bombardier Beetle", "Rare", 3_600, "any", "Sprays a boiling-hot chemical jet at enemies."),
	bug("Volcano", "LavaWasp", "Lava Wasp", "Epic", 14_000, "any", "Flies through ash clouds.", {
		boost = { weather = "Eruption", mult = 3 },
		magic = true,
	}),
	bug("Volcano", "MagmaCentipede", "Magma Centipede", "Legendary", 73_000, "night", "Crawls through cooling lava.", {
		magic = true,
	}),
	bug("Volcano", "PhoenixMoth", "Phoenix Moth", "Mythic", 540_000, "night", "Reborn from the volcano's fire.", {
		weather = "Eruption",
		magic = true,
	}),

	-- Himalayan Peak
	bug("Peak", "SnowFlea", "Snow Flea (springtail)", "Common", 4_000, "any", "Hops across snow even in winter."),
	bug("Peak", "IceCrawler", "Ice Crawler", "Rare", 16_000, "night", "Lives near ice and can die from the warmth of a human hand."),
	bug("Peak", "JumpingSpider", "Himalayan Jumping Spider", "Epic", 60_000, "day", "Lives up to about 6,700 m on Everest, among the highest-living animals."),
	bug("Peak", "BhutanGlory", "Bhutan Glory", "Epic", 60_000, "day", "A rare swallowtail butterfly of the eastern Himalaya."),
	bug("Peak", "KaiserIHind", "Kaiser-i-Hind", "Legendary", 320_000, "dawn", "A rare green swallowtail from Himalayan forests."),
	bug("Peak", "YetiBeetle", "Yeti Beetle", "Mythic", 2_400_000, "any", "Covered in white fur. Legends say it guards the summit.", {
		weather = "Blizzard",
		magic = true,
	}),

	-- Sky Kingdom
	bug("Sky", "PaintedLady", "Painted Lady", "Common", 9_600, "any", "Real painted ladies migrate thousands of km, very high in the sky."),
	bug("Sky", "CloudBee", "Cloud Bee", "Rare", 38_000, "any", "Makes honey from clouds.", { magic = true }),
	bug("Sky", "StormDragonfly", "Storm Dragonfly", "Epic", 140_000, "any", "Rides lightning bolts.", {
		boost = { weather = "Thunderstorm", mult = 3 },
		magic = true,
	}),
	bug("Sky", "AuroraButterfly", "Aurora Butterfly", "Legendary", 760_000, "night", "Its wings shimmer with the northern lights.", {
		weather = "Aurora",
		magic = true,
	}),
	bug("Sky", "StarMoth", "Star Moth", "Legendary", 760_000, "night", "Falls from the sky during meteor showers.", {
		weather = "Meteor shower",
		magic = true,
	}),
	bug("Sky", "RainbowButterfly", "Rainbow Butterfly", "Mythic", 5_700_000, "any", "The rarest bug in the kingdom.", {
		weather = "Rainbow",
		magic = true,
	}),
}

local ById: { [string]: Bug } = {}
local ByZone: { [string]: { Bug } } = {}
for _, b in List do
	assert(ById[b.id] == nil, "duplicate bug id " .. b.id)
	ById[b.id] = b
	local zoneList = ByZone[b.zone]
	if not zoneList then
		zoneList = {}
		ByZone[b.zone] = zoneList
	end
	table.insert(zoneList, b)
end

return {
	List = List,
	ById = ById,
	ByZone = ByZone,
}
