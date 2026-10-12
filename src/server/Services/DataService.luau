--!strict
-- Session-locked player data on DataStores.
--
-- * Loading takes a lock ({JobId, Time}) in the same UpdateAsync that reads the data,
--   so two servers can never both own a player's data (no duplication on rejoin).
-- * Saves only write while this server still holds the lock.
-- * If loading fails, the player plays on defaults with saving disabled, so a
--   DataStore outage can never overwrite real progress.
-- * Autosave every ~2 minutes with jitter, on leave (releasing the lock) and on shutdown.
--
-- In Studio, turn on Game Settings > Security > "Enable Studio Access to API Services"
-- or data will load as defaults and not save (by design, see above).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local Nets = require(ReplicatedStorage.Shared.Config.Nets)

local STORE_NAME = "PlayerData_v1"
local LOCK_TIMEOUT = 30 * 60 -- a lock older than this belongs to a dead server
local AUTOSAVE_SECONDS = 120
local LOAD_ATTEMPTS = 5

export type BagItem = {
	b: string, -- bug id
	v: number, -- coin value
	m: string?, -- weather mutation
	x: { string }?, -- variants (Shiny, Giant, Tiny)
}

export type Data = {
	Version: number,
	Coins: number,
	Nectar: number,
	Gems: number,
	Net: number, -- index into Config/Nets; nets are bought in order
	Zones: { [string]: boolean },
	Bag: { BagItem },
	BagSize: number,
	Bugdex: { [string]: number }, -- bug id -> times caught
	GotGoldenLadybug: boolean,
	Swings: number,
	Catches: number,
	PerfectCatches: number,
}

type Profile = {
	data: Data,
	canSave: boolean,
	key: string,
}

local TEMPLATE: Data = {
	Version = 1,
	Coins = 0,
	Nectar = 0,
	Gems = 0,
	Net = 1,
	Zones = { Meadow = true },
	Bag = {},
	BagSize = Catch.startingBagSize,
	Bugdex = {},
	GotGoldenLadybug = false,
	Swings = 0,
	Catches = 0,
	PerfectCatches = 0,
}

local DataService = {}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local loadedEvent = Instance.new("BindableEvent")
DataService.Loaded = loadedEvent.Event -- (player: Player, data: Data)

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[k] = deepCopy(v)
	end
	return out :: any
end

-- Fill keys added to the template since this player's last save.
local function reconcile(data: { [string]: any }, template: { [string]: any })
	for k, v in template do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

local function loadProfile(player: Player): Profile
	local key = "u_" .. player.UserId
	local fallback: Profile = { data = deepCopy(TEMPLATE), canSave = false, key = key }
	if not store then
		return fallback
	end

	-- In Studio without API access every attempt fails the same way, so don't make
	-- the tester wait through retries.
	local attempts = if RunService:IsStudio() then 1 else LOAD_ATTEMPTS
	for attempt = 1, attempts do
		if not player.Parent then
			return fallback
		end
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key, function(old: any)
				old = old or {}
				local lock = old.Lock
				if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < LOCK_TIMEOUT then
					lockedElsewhere = true
					return nil -- cancel: another server still owns this data
				end
				old.Lock = { JobId = game.JobId, Time = os.time() }
				return old
			end)
		end)
		if ok and not lockedElsewhere and type(result) == "table" then
			local data = result.Data
			if type(data) ~= "table" then
				data = deepCopy(TEMPLATE)
			end
			reconcile(data, TEMPLATE)
			return { data = data :: Data, canSave = true, key = key }
		end
		if not ok then
			warn(string.format("[DataService] load %s attempt %d failed: %s", key, attempt, tostring(result)))
		end
		if attempt < attempts then
			-- Locked elsewhere usually means the old server is still saving; give it time.
			task.wait(if lockedElsewhere then 3 * attempt else 2 ^ attempt)
		end
	end

	warn("[DataService] could not load " .. key .. "; playing on defaults without saving")
	return fallback
end

local function saveProfile(player: Player, profile: Profile, release: boolean): boolean
	if not profile.canSave or not store then
		return false
	end
	local snapshot = deepCopy(profile.data)
	local lostLock = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(profile.key, function(old: any)
			if old and old.Lock and old.Lock.JobId ~= game.JobId then
				lostLock = true
				return nil -- another server took over; never overwrite its data
			end
			return {
				Data = snapshot,
				Lock = if release then nil else { JobId = game.JobId, Time = os.time() },
			}
		end)
	end)
	if not ok then
		warn("[DataService] save failed for " .. profile.key .. ": " .. tostring(err))
	elseif lostLock then
		warn("[DataService] lost session lock for " .. profile.key .. "; saving disabled")
		profile.canSave = false
	end
	return ok and not lostLock
end

-- Mirror the values the HUD needs onto player attributes (replicated, read-only for clients).
function DataService.sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data
	local net = Nets.List[data.Net]
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("BagCount", #data.Bag)
	player:SetAttribute("BagSize", data.BagSize)
	player:SetAttribute("NetName", net.name)
	player:SetAttribute("NetReach", net.reach)
	player:SetAttribute("Species", (function()
		local n = 0
		for _ in data.Bugdex do
			n += 1
		end
		return n
	end)())
	player:SetAttribute("SavingEnabled", profile.canSave)

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value = data.Coins
	end
end

-- Returns nil until the player's data has loaded.
function DataService.get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

-- Robux purchases must only be granted when they can be saved.
function DataService.canSave(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.canSave
end

function DataService.saveNow(player: Player): boolean
	local profile = profiles[player]
	return if profile then saveProfile(player, profile, false) else false
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	leaderstats.Parent = player

	local profile = loadProfile(player)
	if not player.Parent then
		-- Left while loading: release the lock we just took.
		saveProfile(player, profile, true)
		return
	end
	profiles[player] = profile
	DataService.sync(player)
	loadedEvent:Fire(player, profile.data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		saveProfile(player, profile, true)
		profiles[player] = nil
	end
end

function DataService.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable: " .. tostring(result))
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave with per-player jitter so saves don't all land at once.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, profile in profiles do
				task.delay(math.random() * 30, function()
					if profiles[player] == profile then
						saveProfile(player, profile, false)
					end
				end)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
