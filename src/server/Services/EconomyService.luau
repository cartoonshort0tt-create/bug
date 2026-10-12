--!strict
-- Coin sinks and sources at world stations: the Sell Stand, the Net Shop and zone
-- gates. Uses ProximityPrompts, so Roblox checks the player is actually standing
-- there; the server still re-checks everything before changing data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Nets = require(ReplicatedStorage.Shared.Config.Nets)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local EconomyService = {}

local Notify = Remotes.get("Notify")

local function sell(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if #data.Bag == 0 then
		Notify:FireClient(player, "Your bag is empty. Go catch some bugs!")
		return
	end
	local total = 0
	for _, item in data.Bag do
		total += item.v
	end
	local count = #data.Bag
	data.Coins += total
	table.clear(data.Bag)
	DataService.sync(player)
	Notify:FireClient(player, string.format("Sold %d bugs for %s coins!", count, Format.commas(total)))
end

local function buyNextNet(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local nextIndex = data.Net + 1
	local net = Nets.List[nextIndex]
	if not net then
		Notify:FireClient(player, "You already have the best net!")
		return
	end
	if not data.Zones[net.zone] then
		Notify:FireClient(player, string.format("The %s is sold in %s.", net.name, Zones.ById[net.zone].name))
		return
	end
	if data.Coins < net.cost then
		Notify:FireClient(player, string.format("The %s costs %s coins.", net.name, Format.commas(net.cost)))
		return
	end
	data.Coins -= net.cost
	data.Net = nextIndex
	DataService.sync(player)
	Notify:FireClient(player, string.format("You bought the %s! Reach %d, Power %d.", net.name, net.reach, net.power))
end

-- Gates are bought in progression order.
function EconomyService.unlockZone(player: Player, zoneId: string)
	local data = DataService.get(player)
	local zone = Zones.ById[zoneId]
	if not data or not zone then
		return
	end
	if data.Zones[zoneId] then
		Notify:FireClient(player, zone.name .. " is already unlocked.")
		return
	end
	local index = Zones.IndexOf[zoneId]
	local previous = Zones.List[index - 1]
	if previous and not data.Zones[previous.id] then
		Notify:FireClient(player, "Unlock " .. previous.name .. " first.")
		return
	end
	if not zone.released then
		Notify:FireClient(player, zone.name .. " is coming soon!")
		return
	end
	if data.Coins < zone.gatePrice then
		Notify:FireClient(player, string.format("%s costs %s coins.", zone.name, Format.commas(zone.gatePrice)))
		return
	end
	data.Coins -= zone.gatePrice
	data.Zones[zoneId] = true
	DataService.sync(player)
	Notify:FireClient(player, zone.name .. " unlocked!")
end

function EconomyService.start(world: { sellPad: BasePart, netShop: BasePart, forestGate: BasePart })
	local function prompt(part: BasePart): ProximityPrompt
		return part:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	end
	prompt(world.sellPad).Triggered:Connect(sell)
	prompt(world.netShop).Triggered:Connect(buyNextNet)
	prompt(world.forestGate).Triggered:Connect(function(player)
		EconomyService.unlockZone(player, "Forest")
	end)
end

return EconomyService
