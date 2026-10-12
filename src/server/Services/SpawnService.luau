--!strict
-- Keeps each built zone stocked with live bugs, rolled from SpawnOdds with the
-- current global weather and the zone's luck. The server owns position and state;
-- clients only animate. Bugs whose time/weather condition ends fly away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Bugs = require(ReplicatedStorage.Shared.Config.Bugs)
local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local SpawnOdds = require(ReplicatedStorage.Shared.SpawnOdds)
local WeatherClock = require(ReplicatedStorage.Shared.WeatherClock)
local LuckService = require(script.Parent.LuckService)

export type LiveBug = {
	uid: string,
	bug: Bugs.Bug,
	zone: string,
	part: BasePart,
	ownerUserId: number?, -- personal spawns (the scripted Golden Ladybug)
	lockedBy: Player?,
	lockedUntil: number,
}

local TIER_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(167, 179, 169),
	Rare = Color3.fromRGB(106, 168, 245),
	Epic = Color3.fromRGB(181, 140, 244),
	Legendary = Color3.fromRGB(240, 194, 74),
	Mythic = Color3.fromRGB(243, 122, 167),
}

local SpawnService = {}

local live: { [string]: LiveBug } = {}
local countByZone: { [string]: number } = {} -- live shared bugs + slots waiting to respawn
local nextUid = 0
local folder: Folder
local rng = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function playersIn(zoneId: string): { Player }
	-- Prototype: everyone is in the Meadow. Later: read each player's current zone.
	local list = {}
	for _, player in Players:GetPlayers() do
		if (player:GetAttribute("Zone") or "Meadow") == zoneId then
			table.insert(list, player)
		end
	end
	return list
end

local function randomPoint(area: Zones.Area): Vector3
	return Vector3.new(
		area.x + rng:NextNumber(-area.sizeX / 2, area.sizeX / 2),
		area.y,
		area.z + rng:NextNumber(-area.sizeZ / 2, area.sizeZ / 2)
	)
end

local function makePart(bug: Bugs.Bug, position: Vector3, uid: string): BasePart
	local p = Instance.new("Part")
	p.Name = bug.id
	p.Shape = Enum.PartType.Ball
	local size = if bug.tier == "Common" then 1.4 elseif bug.tier == "Rare" then 1.6 else 2
	p.Size = Vector3.new(size, size, size)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.Material = if bug.tier == "Legendary" or bug.tier == "Mythic" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = TIER_COLORS[bug.tier]
	p.Position = position
	p:SetAttribute("Uid", uid)
	p:SetAttribute("BugId", bug.id)
	p:SetAttribute("Tier", bug.tier)
	return p
end

local function spawnBug(zoneId: string, bug: Bugs.Bug, position: Vector3, ownerUserId: number?): LiveBug
	nextUid += 1
	local uid = tostring(nextUid)
	local part = makePart(bug, position, uid)
	if ownerUserId then
		part:SetAttribute("OwnerUserId", ownerUserId)
	end
	part.Parent = folder
	local entry: LiveBug = {
		uid = uid,
		bug = bug,
		zone = zoneId,
		part = part,
		ownerUserId = ownerUserId,
		lockedBy = nil,
		lockedUntil = 0,
	}
	live[uid] = entry
	if not ownerUserId then
		countByZone[zoneId] = (countByZone[zoneId] or 0) + 1
	end
	return entry
end

local function spawnRandom(zoneId: string)
	local zone = Zones.ById[zoneId]
	local area = zone.area
	if not area then
		return
	end
	local t = now()
	local state = WeatherClock.stateAt(zoneId, t)
	local luck = LuckService.forZone(playersIn(zoneId), t)
	local bug = SpawnOdds.pick(zoneId, {
		phase = state.phase,
		weather = state.weather,
		rainbow = state.rainbow,
	}, luck, rng:NextNumber())
	if bug then
		spawnBug(zoneId, bug, randomPoint(area))
	end
end

function SpawnService.get(uid: string): LiveBug?
	return live[uid]
end

-- Removes a bug (caught or expired). Shared bugs are replaced after a short delay.
function SpawnService.remove(uid: string)
	local entry = live[uid]
	if not entry then
		return
	end
	live[uid] = nil
	entry.part:Destroy()
	if not entry.ownerUserId then
		-- The zone count keeps this slot until the replacement spawns, so the
		-- top-up loop never double-fills it.
		local delay = rng:NextNumber(Catch.respawnDelay[1], Catch.respawnDelay[2])
		task.delay(delay, function()
			countByZone[entry.zone] -= 1
			spawnRandom(entry.zone)
		end)
	end
end

-- A bug only one player can see as theirs and catch (e.g. the first Golden Ladybug).
function SpawnService.spawnPersonal(player: Player, bugId: string): LiveBug?
	local bug = Bugs.ById[bugId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not bug or not root or not root:IsA("BasePart") then
		return nil
	end
	local offset = Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
	local position = Vector3.new(root.Position.X, 3, root.Position.Z) + offset
	return spawnBug(bug.zone, bug, position, player.UserId)
end

function SpawnService.hasPersonal(player: Player, bugId: string): boolean
	for _, entry in live do
		if entry.ownerUserId == player.UserId and entry.bug.id == bugId then
			return true
		end
	end
	return false
end

-- Bugs whose conditions ended (night bugs at sunrise, storm bugs after the storm) fly away.
local function expireUnavailable()
	local t = now()
	local stateByZone: { [string]: WeatherClock.State } = {}
	for uid, entry in live do
		if not entry.ownerUserId then
			local state = stateByZone[entry.zone]
			if not state then
				state = WeatherClock.stateAt(entry.zone, t)
				stateByZone[entry.zone] = state
			end
			local ok = SpawnOdds.isAvailable(entry.bug, {
				phase = state.phase,
				weather = state.weather,
				rainbow = state.rainbow,
			})
			if not ok and (entry.lockedBy == nil or entry.lockedUntil < t) then
				SpawnService.remove(uid)
			end
		end
	end
end

function SpawnService.start(bugsFolder: Folder)
	folder = bugsFolder
	for _, zone in Zones.List do
		if zone.area then
			countByZone[zone.id] = 0
			for _ = 1, zone.liveBugs do
				spawnRandom(zone.id)
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(5)
			expireUnavailable()
			-- Top up in case a respawn was lost (e.g. a zone emptied by expiry).
			for _, zone in Zones.List do
				if zone.area and (countByZone[zone.id] or 0) < zone.liveBugs then
					spawnRandom(zone.id)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for uid, entry in live do
			if entry.ownerUserId == player.UserId then
				SpawnService.remove(uid)
			end
		end
	end)
end

return SpawnService
