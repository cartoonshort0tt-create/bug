--!strict
-- Saved data. Everything here is written with atomic UpdateAsync/IncrementAsync merges,
-- so two servers can never overwrite each other and nothing needs a session lock:
--   * best time: only ever goes up (max merge) — an OrderedDataStore, which is also
--     the all-time leaderboard
--   * Robux spent: only ever goes up (increment) — an OrderedDataStore, the
--     supporters leaderboard
--   * Continue credits: a paid Continue is recorded together with its PurchaseId in
--     one atomic write, so a purchase is granted exactly once even if Roblox retries.
--     Credits are kept per price step.
--
-- In Studio, turn on Game Settings > Security > "Enable Studio Access to API Services".

local DataStoreService = game:GetService("DataStoreService")

local Store = {}

local bestStore: OrderedDataStore? = nil
local spentStore: OrderedDataStore? = nil
local creditStore: DataStore? = nil

local RECEIPTS_KEPT = 50

local function retry<T>(label: string, fn: () -> T): (boolean, T?)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(string.format("[Store] %s failed (attempt %d): %s", label, attempt, tostring(result)))
		if attempt < 3 then
			task.wait(2 ^ attempt)
		end
	end
	return false, nil
end

function Store.start()
	local ok, err = pcall(function()
		bestStore = DataStoreService:GetOrderedDataStore("BestTime_v1")
		spentStore = DataStoreService:GetOrderedDataStore("RobuxSpent_v1")
		creditStore = DataStoreService:GetDataStore("Continues_v1")
	end)
	if not ok then
		warn("[Store] DataStores unavailable: " .. tostring(err))
	end
end

function Store.available(): boolean
	return bestStore ~= nil
end

function Store.getBest(userId: number): number
	local s = bestStore
	if not s then
		return 0
	end
	local ok, value = retry("getBest", function()
		return s:GetAsync(tostring(userId))
	end)
	return if ok and type(value) == "number" then value else 0
end

-- Saves `seconds` if it beats the stored best. Returns the best after the write.
function Store.submitBest(userId: number, seconds: number): number
	local s = bestStore
	local whole = math.floor(seconds)
	if not s or whole <= 0 then
		return whole
	end
	local ok, result = retry("submitBest", function()
		return s:UpdateAsync(tostring(userId), function(old: number?): number
			if old and old >= whole then
				return old -- keep the existing, higher best
			end
			return whole
		end)
	end)
	if ok and type(result) == "number" then
		return result
	end
	return whole
end

function Store.getSpent(userId: number): number
	local s = spentStore
	if not s then
		return 0
	end
	local ok, value = retry("getSpent", function()
		return s:GetAsync(tostring(userId))
	end)
	return if ok and type(value) == "number" then value else 0
end

-- Records a Continue purchase for price step `step`: +1 credit for that step and the
-- PurchaseId, in one atomic write. Credits are per step, so a cheap early Continue can
-- never be saved up and spent on a later, pricier one.
-- Returns (recorded, isNew): recorded = granted now or before; isNew = granted now.
function Store.recordPurchase(userId: number, purchaseId: string, step: number): (boolean, boolean)
	local s = creditStore
	if not s then
		return false, false
	end
	local isNew = false
	local ok = retry("recordPurchase", function()
		return s:UpdateAsync("u_" .. userId, function(old: any)
			isNew = false
			local record = if type(old) == "table" then old else {}
			record.c = record.c or {}
			record.r = record.r or {}
			if table.find(record.r, purchaseId) then
				return nil -- already granted; nothing to change
			end
			local key = tostring(step)
			record.c[key] = (record.c[key] or 0) + 1
			table.insert(record.r, purchaseId)
			while #record.r > RECEIPTS_KEPT do
				table.remove(record.r, 1)
			end
			isNew = true
			return record
		end)
	end)
	return ok, ok and isNew
end

-- Spends one Continue credit for price step `step` if the player has one.
function Store.spendCredit(userId: number, step: number): boolean
	local s = creditStore
	if not s then
		return false
	end
	local spent = false
	local ok = retry("spendCredit", function()
		return s:UpdateAsync("u_" .. userId, function(old: any)
			spent = false
			local key = tostring(step)
			if type(old) ~= "table" or type(old.c) ~= "table" or (old.c[key] or 0) <= 0 then
				return nil
			end
			old.c[key] -= 1
			spent = true
			return old
		end)
	end)
	return ok and spent
end

function Store.addSpent(userId: number, robux: number)
	local s = spentStore
	if not s or robux <= 0 then
		return
	end
	retry("addSpent", function()
		return s:IncrementAsync(tostring(userId), math.floor(robux))
	end)
end

export type Entry = { userId: number, value: number }

function Store.top(which: "best" | "spent", count: number): { Entry }
	local s = if which == "best" then bestStore else spentStore
	if not s then
		return {}
	end
	local ok, pages = retry("top " .. which, function()
		return (s :: OrderedDataStore):GetSortedAsync(false, count)
	end)
	local out: { Entry } = {}
	if ok and pages then
		for _, item in (pages :: DataStorePages):GetCurrentPage() do
			local userId = tonumber(item.key)
			if userId and type(item.value) == "number" then
				table.insert(out, { userId = userId, value = item.value })
			end
		end
	end
	return out
end

return Store
