--!strict
-- Rarity tiers: base spawn weights, how strongly luck lifts each tier, and the
-- value multiplier that sets every bug's coin value (zone base × multiplier).

export type Tier = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

local Rarity = {}

local Order: { Tier } = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
Rarity.Order = Order

Rarity.BaseWeight = {
	Common = 70,
	Rare = 22,
	Epic = 6.5,
	Legendary = 1.4,
	Mythic = 0.1,
} :: { [string]: number }

-- weight = baseWeight × (1 + luck) ^ exponent, so luck mostly lifts the top tiers.
Rarity.LuckExponent = {
	Common = 0,
	Rare = 0.6,
	Epic = 0.9,
	Legendary = 1.1,
	Mythic = 1.3,
} :: { [string]: number }

Rarity.ValueMultiplier = {
	Common = 1,
	Rare = 4,
	Epic = 15,
	Legendary = 80,
	Mythic = 600,
} :: { [string]: number }

-- Total luck is a fraction: 1.0 means +100%. Capped at +400%.
Rarity.MaxLuck = 4

return Rarity
