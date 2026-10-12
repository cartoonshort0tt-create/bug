--!strict
-- Total luck per player (a fraction: 0.5 = +50%). Prototype sources: net and combo.
-- Pets, Bugdex pages, party, Metamorphosis, group and potions plug in here later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local Nets = require(ReplicatedStorage.Shared.Config.Nets)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local DataService = require(script.Parent.DataService)

local LuckService = {}

type Combo = { stacks: number, expiresAt: number }
local combos: { [Player]: Combo } = {}

function LuckService.setCombo(player: Player, stacks: number, expiresAt: number)
	combos[player] = { stacks = math.clamp(stacks, 0, Catch.comboMaxStacks), expiresAt = expiresAt }
end

function LuckService.comboStacks(player: Player, now: number): number
	local combo = combos[player]
	if combo and combo.expiresAt > now then
		return combo.stacks
	end
	return 0
end

function LuckService.forPlayer(player: Player, now: number): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local luck = Nets.List[data.Net].luck
	luck += LuckService.comboStacks(player, now) * Catch.comboLuckPerStack
	return math.clamp(luck, 0, Rarity.MaxLuck)
end

-- Spawns are shared, so a zone uses the average luck of the players in it.
function LuckService.forZone(players: { Player }, now: number): number
	if #players == 0 then
		return 0
	end
	local sum = 0
	for _, player in players do
		sum += LuckService.forPlayer(player, now)
	end
	return sum / #players
end

Players.PlayerRemoving:Connect(function(player)
	combos[player] = nil
end)

return LuckService
