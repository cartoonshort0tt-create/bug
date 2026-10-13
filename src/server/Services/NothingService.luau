--!strict
-- The game: sit in a booth chair, a 3-second "Hands off!" countdown, then the timer
-- runs until the player does anything at all. The server owns the clock; the client
-- only reports input. Standing up (or jumping out) is detected on the server.
--
-- Also handles Continue / Restart, the 18-minute idle re-join, and the booth screens.

local MarketplaceService = game:GetService("MarketplaceService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Run = require(ReplicatedStorage.Shared.Run)
local Leaderboards = require(script.Parent.Leaderboards)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local Store = require(script.Parent.Store)

type PlayerState = {
	run: Run.State,
	booth: LobbyBuilder.Booth?,
	best: number,
	runningSince: number?, -- start of the current stretch without an idle re-join
	teleporting: boolean,
	pendingResume: { banked: number, continues: number }?,
	awaitingPurchase: number?, -- price step the player was prompted to buy
	lastRequest: number,
}

local NothingService = {}

local states: { [Player]: PlayerState } = {}
local boothOwner: { [LobbyBuilder.Booth]: Player } = {}
local lobby: LobbyBuilder.Lobby
local resumeMap: MemoryStoreHashMap? = nil
local priceCache: { [number]: number } = {}

local Notify = Remotes.get("Notify")

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- What the next Continue costs. Prices are read from Roblox in the background (see
-- prefetchPrices) so regional pricing or Creator Hub changes show correctly; until a
-- price has loaded, the price from Config is shown.
local function priceFor(step: number): number?
	local product = Config.continueProducts[step]
	if not product then
		return nil
	end
	return priceCache[product.productId] or product.price
end

local function prefetchPrices()
	for _, product in Config.continueProducts do
		if product.productId ~= 0 then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.productId, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				priceCache[product.productId] = info.PriceInRobux
			end
		end
	end
end

-- Mirror the run onto player attributes; the client reads them for the HUD and input watching.
local function publish(player: Player, s: PlayerState)
	local run = s.run
	player:SetAttribute("RunPhase", run.phase)
	player:SetAttribute("RunOffset", run.offset)
	player:SetAttribute("RunStartedAt", run.startedAt)
	player:SetAttribute("RunCountdownEndsAt", run.countdownEndsAt)
	player:SetAttribute("RunLostTime", run.lostTime)
	player:SetAttribute("RunContinueReady", run.continueReady)
	player:SetAttribute("BoothIndex", if s.booth then s.booth.index else nil)
	player:SetAttribute("Best", s.best)
	local step = Run.nextContinueStep(run)
	local product = Config.continueProducts[step]
	local purchasable = product ~= nil and (product.productId ~= 0 or RunService:IsStudio())
	player:SetAttribute("NextContinuePrice", if purchasable then priceFor(step) else nil)

	local leaderstats = player:FindFirstChild("leaderstats")
	local bestValue = leaderstats and leaderstats:FindFirstChild("Best")
	if bestValue and bestValue:IsA("StringValue") then
		bestValue.Value = Format.duration(s.best)
	end
end

local function finishRun(player: Player, s: PlayerState, finished: number?)
	Leaderboards.clearLive(player)
	s.runningSince = nil
	if finished and finished > s.best then
		s.best = math.floor(finished)
		task.spawn(function()
			s.best = math.max(s.best, Store.submitBest(player.UserId, finished))
			publish(player, s)
			Leaderboards.refreshSoon()
		end)
	end
end

local function setRun(player: Player, s: PlayerState, run: Run.State, finished: number?)
	local was = s.run.phase
	s.run = run
	if run.phase == "running" and was ~= "running" then
		s.runningSince = now()
		Leaderboards.setLive(player, run.offset, run.startedAt :: number)
	elseif was == "running" and run.phase ~= "running" then
		finishRun(player, s, finished)
	end
	publish(player, s)
end

local function seated(s: PlayerState): boolean
	return s.booth ~= nil
end

local function applyContinue(player: Player, s: PlayerState)
	s.awaitingPurchase = nil
	setRun(player, s, Run.continue(s.run, now(), seated(s), Config.countdownSeconds))
	if not seated(s) then
		Notify:FireClient(player, "Continue ready. Sit in a booth to pick up where you left off.")
	end
end

-- Booth chairs ------------------------------------------------------------------

local function onOccupantChanged(booth: LobbyBuilder.Booth)
	local occupant = booth.seat.Occupant
	local previous = boothOwner[booth]
	local player = if occupant then Players:GetPlayerFromCharacter(occupant.Parent) else nil

	if previous and previous ~= player then
		boothOwner[booth] = nil
		local s = states[previous]
		if s and s.booth == booth then
			s.booth = nil
			local run, finished = Run.stand(s.run, now())
			setRun(previous, s, run, finished)
		end
	end

	if player then
		local s = states[player]
		if not s then
			return
		end
		boothOwner[booth] = player
		s.booth = booth
		local resume = s.pendingResume
		if resume then
			s.pendingResume = nil
			setRun(player, s, Run.resume(resume.banked, resume.continues, now(), Config.countdownSeconds))
		else
			setRun(player, s, Run.sit(s.run, now(), Config.countdownSeconds))
		end
	end
end

-- Remote requests (all arguments untrusted) ------------------------------------------

local function throttled(s: PlayerState): boolean
	local t = os.clock()
	if t - s.lastRequest < 0.25 then
		return true
	end
	s.lastRequest = t
	return false
end

local function onMoved(player: Player)
	local s = states[player]
	if not s or (s.run.phase ~= "running" and s.run.phase ~= "countdown") then
		return
	end
	local run, finished = Run.moved(s.run, now(), Config.countdownSeconds)
	setRun(player, s, run, finished)
end

local function onRestart(player: Player)
	local s = states[player]
	if not s or throttled(s) then
		return
	end
	s.awaitingPurchase = nil
	setRun(player, s, Run.restart(s.run, now(), seated(s), Config.countdownSeconds))
end

local function onContinue(player: Player)
	local s = states[player]
	if not s or throttled(s) or s.run.phase ~= "lost" or s.run.continueReady then
		return
	end
	local step = Run.nextContinueStep(s.run)
	local product = Config.continueProducts[step]
	if not product then
		Notify:FireClient(player, "That's every Continue there is. Time to Restart.")
		return
	end

	-- A Continue bought earlier for this exact price step (e.g. before a disconnect).
	if Store.spendCredit(player.UserId, step) then
		applyContinue(player, s)
		return
	end

	if product.productId == 0 then
		if RunService:IsStudio() then
			Notify:FireClient(player, "Studio test: free Continue (no product ID set yet).")
			applyContinue(player, s)
		else
			Notify:FireClient(player, "Continue isn't available right now.")
		end
		return
	end

	s.awaitingPurchase = step
	MarketplaceService:PromptProductPurchase(player, product.productId)
end

-- Called by Purchases after a Continue purchase for `step` is safely recorded.
function NothingService.onContinuePurchased(player: Player, step: number)
	local s = states[player]
	if not s or s.awaitingPurchase ~= step or s.run.phase ~= "lost" then
		return -- the credit stays saved for this price step
	end
	if Store.spendCredit(player.UserId, step) then
		applyContinue(player, s)
	end
end

-- Idle re-join -------------------------------------------------------------------
-- Roblox disconnects players after about 20 minutes without input. At 18 minutes the
-- run is saved (server-side only; nothing comes from the client) and the player is
-- re-joined to this place, where the run resumes with the time spent re-joining banked.

local function refreshIdle(player: Player, s: PlayerState)
	local map = resumeMap
	if not map or s.teleporting then
		return
	end
	local t = now()
	local elapsed = Run.elapsed(s.run, t)
	s.teleporting = true
	task.spawn(function()
		Store.submitBest(player.UserId, elapsed)
		local saved = pcall(function()
			map:SetAsync(tostring(player.UserId), { b = elapsed, c = s.run.continues, t = os.time() }, Config.resumeWindowSeconds)
		end)
		local ok, err = false, "resume not saved"
		if saved then
			ok, err = pcall(function()
				TeleportService:TeleportAsync(game.PlaceId, { player })
			end)
		end
		if not ok then
			warn("[NothingService] idle re-join failed for " .. player.Name .. ": " .. tostring(err))
			s.teleporting = false
			-- Try again in a minute; Roblox kicks at about 20 minutes.
			s.runningSince = now() - Config.idleRefreshSeconds + 60
		end
	end)
end

local function loadResume(player: Player): { banked: number, continues: number }?
	local map = resumeMap
	if not map then
		return nil
	end
	local ok, value = pcall(function()
		return map:GetAsync(tostring(player.UserId))
	end)
	if not ok or type(value) ~= "table" or type(value.b) ~= "number" or type(value.t) ~= "number" then
		return nil
	end
	pcall(function()
		map:RemoveAsync(tostring(player.UserId))
	end)
	local gap = os.time() - value.t
	if gap < 0 or gap > Config.resumeWindowSeconds then
		return nil
	end
	return { banked = value.b + gap, continues = if type(value.c) == "number" then value.c else 0 }
end

local function seatInFreeBooth(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	task.wait(1)
	for _, booth in lobby.booths do
		if not booth.seat.Occupant and not boothOwner[booth] then
			booth.seat:Sit(humanoid)
			return
		end
	end
end

-- Players ----------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local best = Instance.new("StringValue")
	best.Name = "Best"
	best.Value = "0:00"
	best.Parent = leaderstats
	leaderstats.Parent = player

	local s: PlayerState = {
		run = Run.new(),
		booth = nil,
		best = 0,
		runningSince = nil,
		teleporting = false,
		pendingResume = nil,
		awaitingPurchase = nil,
		lastRequest = 0,
	}
	states[player] = s
	publish(player, s)

	task.spawn(function()
		s.best = math.max(s.best, Store.getBest(player.UserId))
		if states[player] == s then
			publish(player, s)
		end
	end)

	local resume = loadResume(player)
	if resume then
		s.pendingResume = resume
		task.spawn(seatInFreeBooth, player)
	end
end

local function onPlayerRemoving(player: Player)
	local s = states[player]
	if not s then
		return
	end
	if s.booth then
		boothOwner[s.booth] = nil
	end
	if s.run.phase == "running" and not s.teleporting then
		-- Left (or was disconnected) while doing nothing: that time still counts.
		task.spawn(Store.submitBest, player.UserId, Run.elapsed(s.run, now()))
	end
	Leaderboards.clearLive(player)
	states[player] = nil
end

-- Booth screens --------------------------------------------------------------------

local function renderBooth(booth: LobbyBuilder.Booth, t: number)
	local screen = booth.screen
	local player = boothOwner[booth]
	local s = player and states[player]
	if not player or not s then
		screen.header.Text = string.format("BOOTH %02d", booth.index)
		screen.live.Text = ""
		screen.timer.Text = "--:--"
		screen.status.Text = "FREE. SIT DOWN TO START DOING NOTHING."
		screen.footer.Text = ""
		return
	end
	local run = s.run
	screen.header.Text = string.format("BOOTH %02d · %s", booth.index, player.DisplayName)
	screen.live.Text = if run.phase == "running" then "● LIVE" else ""
	if run.phase == "countdown" then
		screen.timer.Text = tostring(math.max(1, math.ceil((run.countdownEndsAt :: number) - t)))
		screen.status.Text = if run.offset > 0 then "HANDS OFF. CONTINUING FROM " .. Format.duration(run.offset) else "HANDS OFF. DON'T TOUCH ANYTHING."
	elseif run.phase == "running" then
		screen.timer.Text = Format.duration(Run.elapsed(run, t))
		screen.status.Text = "TIME SPENT ACHIEVING NOTHING"
	elseif run.phase == "lost" then
		screen.timer.Text = Format.duration(Run.elapsed(run, t))
		screen.status.Text = "YOU MOVED."
	else
		screen.timer.Text = "0:00"
		screen.status.Text = ""
	end
	screen.footer.Text = "YOUR BEST " .. Format.duration(s.best)
end

-- Start ---------------------------------------------------------------------------

function NothingService.start(builtLobby: LobbyBuilder.Lobby)
	lobby = builtLobby
	task.spawn(prefetchPrices)

	local ok, map = pcall(function()
		return MemoryStoreService:GetHashMap("Resume_v1")
	end)
	if ok then
		resumeMap = map
	end

	for _, booth in lobby.booths do
		booth.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			onOccupantChanged(booth)
		end)
	end

	Remotes.get("Moved").OnServerEvent:Connect(onMoved)
	Remotes.get("Restart").OnServerEvent:Connect(onRestart)
	Remotes.get("Continue").OnServerEvent:Connect(onContinue)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Countdowns, idle re-joins and booth screens.
	local lastScreens = 0
	RunService.Heartbeat:Connect(function()
		local t = now()
		for player, s in states do
			if s.run.phase == "countdown" then
				local ticked = Run.tick(s.run, t)
				if ticked ~= s.run then
					setRun(player, s, ticked)
				end
			elseif s.run.phase == "running" and s.runningSince and not RunService:IsStudio() then
				if t - s.runningSince >= Config.idleRefreshSeconds then
					refreshIdle(player, s)
				end
			end
		end
		if os.clock() - lastScreens >= 0.25 then
			lastScreens = os.clock()
			for _, booth in lobby.booths do
				renderBooth(booth, t)
			end
		end
	end)
end

return NothingService
