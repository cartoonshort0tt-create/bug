--!strict
-- The one ProcessReceipt handler for the game. Each Continue price step is its own
-- Developer Product (see Config). A purchase is recorded together with its PurchaseId
-- in one atomic DataStore write before Roblox is told it was granted, so it is
-- granted exactly once even if Roblox retries the receipt.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Leaderboards = require(script.Parent.Leaderboards)
local NothingService = require(script.Parent.NothingService)
local Store = require(script.Parent.Store)

local Purchases = {}

function Purchases.start()
	local stepByProduct: { [number]: number } = {}
	for step, product in Config.continueProducts do
		if product.productId ~= 0 then
			stepByProduct[product.productId] = step
		end
	end

	MarketplaceService.ProcessReceipt = function(receipt)
		local step = stepByProduct[receipt.ProductId]
		if not step or not Store.available() then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local recorded, isNew = Store.recordPurchase(receipt.PlayerId, receipt.PurchaseId, step)
		if not recorded then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox will retry
		end
		if isNew then
			-- CurrencySpent is what the player actually paid (regional pricing included).
			Store.addSpent(receipt.PlayerId, receipt.CurrencySpent)
			Leaderboards.refreshSoon()
		end
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if player then
			task.spawn(NothingService.onContinuePurchased, player, step)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Purchases
