--!strict
-- Server-authoritative catching with a lag-tolerant timing ring.
--
-- 1. Client asks for a ring on a bug (RequestRing). Server checks the player, the
--    bug, reach, net Power, bag space and cooldowns, reserves the bug, and stamps
--    the ring start on the shared clock: start = workspace:GetServerTimeNow().
-- 2. Client draws the ring from `start` using its own GetServerTimeNow(), so what the
--    player sees matches the server's timeline.
-- 3. On tap the client sends Swing(ringId, hitTime) with the synced clock value.
-- 4. Server judges the ring phase AT hitTime (not arrival time), so ping does not turn
--    a good swing into a miss, and rejects hit times from the future or too far past.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local Nets = require(ReplicatedStorage.Shared.Config.Nets)
local Weather = require(ReplicatedStorage.Shared.Config.Weather)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeatherClock = require(ReplicatedStorage.Shared.WeatherClock)
local DataService = require(script.Parent.DataService)
local LuckService = require(script.Parent.LuckService)
local SpawnService = require(script.Parent.SpawnService)

type Ring = {
	id: number,
	uid: string,
	start: number,
	duration: number,
	green: { number },
	perfect: { number },
}

type PlayerState = {
	ring: Ring?,
	nextRingId: number,
	lastRingRequest: number,
	lastSwing: number,
	perfectStreak: number,
	-- rate limiting: token bucket over all catch remotes
	tokens: number,
	tokensAt: number,
	-- anti-cheat signal
	watchedSwings: number,
	watchedPerfects: number,
	flagged: boolean,
}

local RATE_PER_SECOND = 8
local RATE_BURST = 12

local CatchService = {}

local states: { [Player]: PlayerState } = {}
local rng = Random.new()

local RingStarted = Remotes.get("RingStarted")
local CatchResult = Remotes.get("CatchResult")
local Notify = Remotes.get("Notify")

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function stateFor(player: Player): PlayerState
	local s = states[player]
	if not s then
		s = {
			ring = nil,
			nextRingId = 0,
			lastRingRequest = -math.huge,
			lastSwing = -math.huge,
			perfectStreak = 0,
			tokens = RATE_BURST,
			tokensAt = os.clock(),
			watchedSwings = 0,
			watchedPerfects = 0,
			flagged = false,
		}
		states[player] = s
	end
	return s
end

local function allow(s: PlayerState): boolean
	local t = os.clock()
	s.tokens = math.min(RATE_BURST, s.tokens + (t - s.tokensAt) * RATE_PER_SECOND)
	s.tokensAt = t
	if s.tokens < 1 then
		return false
	end
	s.tokens -= 1
	return true
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function inReach(player: Player, bugPart: BasePart, reach: number): boolean
	local pos = rootPosition(player)
	if not pos then
		return false
	end
	-- Compare on the ground plane; bugs hover at different heights.
	local a = Vector3.new(pos.X, 0, pos.Z)
	local b = Vector3.new(bugPart.Position.X, 0, bugPart.Position.Z)
	return (a - b).Magnitude <= reach + Catch.reachToleranceStuds
end

local function ringExpired(ring: Ring, t: number): boolean
	return t > ring.start + ring.duration + Catch.graceSeconds + 1
end

local function releaseRing(s: PlayerState)
	local ring = s.ring
	s.ring = nil
	if ring then
		local entry = SpawnService.get(ring.uid)
		if entry and entry.lockedBy then
			entry.lockedBy = nil
			entry.lockedUntil = 0
		end
	end
end

local function onRequestRing(player: Player, uid: unknown)
	if type(uid) ~= "string" or #uid > 16 then
		return
	end
	local s = stateFor(player)
	if not allow(s) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local t = now()

	if t - s.lastRingRequest < Catch.ringRequestCooldown then
		return
	end
	s.lastRingRequest = t
	if s.ring and not ringExpired(s.ring, t) then
		return
	end
	releaseRing(s)

	local net = Nets.List[data.Net]
	if t - s.lastSwing < Catch.baseSwingCooldown / net.speed then
		return
	end

	local entry = SpawnService.get(uid)
	if not entry then
		return
	end
	if entry.ownerUserId and entry.ownerUserId ~= player.UserId then
		return
	end
	if entry.lockedBy and entry.lockedBy ~= player and entry.lockedUntil > t then
		Notify:FireClient(player, "Someone else is catching that bug!")
		return
	end
	if not inReach(player, entry.part, net.reach) then
		return
	end
	if entry.bug.power and net.power < entry.bug.power then
		Notify:FireClient(player, string.format("%s needs a net with Power %d.", entry.bug.name, entry.bug.power))
		return
	end
	if #data.Bag >= data.BagSize then
		Notify:FireClient(player, "Your bag is full! Sell at the Sell Stand.")
		return
	end

	entry.lockedBy = player
	entry.lockedUntil = t + Catch.bugLockSeconds

	s.nextRingId += 1
	local tutorial = data.Swings < Catch.tutorialSwings
	local ring: Ring = {
		id = s.nextRingId,
		uid = uid,
		start = t,
		duration = Catch.ringDuration,
		green = if tutorial then Catch.tutorialGreen else Catch.green,
		perfect = Catch.perfect,
	}
	s.ring = ring
	RingStarted:FireClient(player, {
		id = ring.id,
		uid = ring.uid,
		start = ring.start,
		duration = ring.duration,
		green = ring.green,
		perfect = ring.perfect,
	})
end

local function rollVariants(): ({ string }?, number)
	local names: { string } = {}
	local mult = 1
	for _, variant in Catch.variants do
		-- Giant and Tiny can't both happen.
		local blocked = (variant.name == "Tiny" and table.find(names, "Giant") ~= nil)
		if not blocked and rng:NextNumber() < variant.chance then
			table.insert(names, variant.name)
			mult *= variant.mult
		end
	end
	return if #names > 0 then names else nil, mult
end

local function onSwing(player: Player, ringId: unknown, hitTime: unknown)
	if type(ringId) ~= "number" or type(hitTime) ~= "number" or hitTime ~= hitTime then
		return
	end
	local s = stateFor(player)
	if not allow(s) then
		return
	end
	local data = DataService.get(player)
	local ring = s.ring
	if not data or not ring or ring.id ~= ringId then
		return
	end
	local t = now()
	releaseRing(s) -- consume the ring: one swing per ring
	s.lastSwing = t
	data.Swings += 1

	local function miss(reason: string)
		s.perfectStreak = 0
		CatchResult:FireClient(player, { ok = false, reason = reason })
	end

	-- Lag-tolerant timing checks.
	if hitTime > t + Catch.futureToleranceSeconds then
		return miss("Missed!") -- claims to be from the future: never trust it
	end
	local ping = player:GetNetworkPing()
	if hitTime < t - (ping * 2 + Catch.staleBaseSeconds) then
		return miss("Too slow!")
	end
	local p = (hitTime - ring.start) / ring.duration
	local grace = Catch.graceSeconds / ring.duration
	if p < ring.green[1] - grace or p > ring.green[2] + grace then
		return miss(if p < ring.green[1] then "Too early!" else "Too late!")
	end

	local entry = SpawnService.get(ring.uid)
	if not entry then
		return miss("It flew away!")
	end
	local net = Nets.List[data.Net]
	if not inReach(player, entry.part, net.reach) then
		return miss("Out of reach!")
	end
	if #data.Bag >= data.BagSize then
		return miss("Your bag is full!")
	end

	local bug = entry.bug
	local perfect = p >= ring.perfect[1] and p <= ring.perfect[2]

	-- Value: base (or the first-catch bonus), variants, weather mutation, perfect bonus.
	local base = bug.value
	if bug.firstCatchValue and bug.id == "GoldenLadybug" and not data.GotGoldenLadybug then
		base = bug.firstCatchValue
		data.GotGoldenLadybug = true
	end
	local variants, mult = rollVariants()
	local mutationName: string? = nil
	local state = WeatherClock.stateAt(entry.zone, t)
	if state.mutation and rng:NextNumber() < Weather.MutationChance then
		mutationName = state.mutation.name
		mult *= state.mutation.mult
	end
	if perfect then
		mult *= 1 + Catch.perfectBonus
	end
	local value = math.max(1, math.floor(base * mult + 0.5))

	table.insert(data.Bag, { b = bug.id, v = value, m = mutationName, x = variants })
	local newSpecies = data.Bugdex[bug.id] == nil
	data.Bugdex[bug.id] = (data.Bugdex[bug.id] or 0) + 1
	data.Catches += 1
	SpawnService.remove(entry.uid)

	-- Combo: every N perfect catches in a row adds a luck stack for 60 s.
	if perfect then
		data.PerfectCatches += 1
		s.perfectStreak += 1
		if s.perfectStreak % Catch.comboPerfects == 0 then
			local stacks = math.min(Catch.comboMaxStacks, LuckService.comboStacks(player, t) + 1)
			LuckService.setCombo(player, stacks, t + Catch.comboSeconds)
			Notify:FireClient(player, string.format("Combo! +%d%% luck for 60 s", stacks * Catch.comboLuckPerStack * 100))
		end
	else
		s.perfectStreak = 0
	end

	-- Anti-cheat signal: humans don't hit perfect 90% of the time over 200 swings.
	s.watchedSwings += 1
	if perfect then
		s.watchedPerfects += 1
	end
	if not s.flagged and s.watchedSwings >= Catch.perfectWatchSwings
		and s.watchedPerfects / s.watchedSwings > Catch.perfectWatchRate
	then
		s.flagged = true
		warn(string.format("[CatchService] flag: %s perfect rate %.0f%%", player.Name, 100 * s.watchedPerfects / s.watchedSwings))
	end

	-- The scripted first-session surprise.
	if data.Catches >= Catch.goldenLadybugAfterCatches and not data.GotGoldenLadybug
		and not SpawnService.hasPersonal(player, "GoldenLadybug")
	then
		SpawnService.spawnPersonal(player, "GoldenLadybug")
		Notify:FireClient(player, "Something golden is sparkling nearby...")
	end

	DataService.sync(player)
	CatchResult:FireClient(player, {
		ok = true,
		bugId = bug.id,
		name = bug.name,
		tier = bug.tier,
		value = value,
		valueText = Format.commas(value),
		mutation = mutationName,
		variants = variants,
		perfect = perfect,
		newSpecies = newSpecies,
		fact = if newSpecies then bug.fact else nil,
	})
end

function CatchService.start()
	Remotes.get("RequestRing").OnServerEvent:Connect(onRequestRing)
	Remotes.get("Swing").OnServerEvent:Connect(onSwing)
	Players.PlayerRemoving:Connect(function(player)
		local s = states[player]
		if s then
			releaseRing(s)
		end
		states[player] = nil
	end)
end

return CatchService
