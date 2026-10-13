--!strict
-- The two lobby boards.
--
-- Longest time doing nothing: all-time best times (refreshed every minute) merged with
-- everyone sitting right now in ANY server. Each server publishes its live runs to a
-- MemoryStore sorted map every few seconds; every server reads it back, so live rows
-- tick up every second and climb past others as they go.
--
-- Top supporters: Robux spent on Continues, all-time.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local Store = require(script.Parent.Store)

local Leaderboards = {}

type LiveRun = { userId: number, name: string, banked: number, since: number }

-- Each server sets these for its own running players.
local localLive: { [number]: LiveRun } = {}
-- Read back from every server.
local sharedLive: { [number]: LiveRun } = {}
local topBest: { Store.Entry } = {}
local topSpent: { Store.Entry } = {}
local names: { [number]: string } = {}

local liveMap: MemoryStoreSortedMap? = nil
local SORT_OFFSET = 4e9 -- keeps sort keys positive

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok and type(result) == "string" then result else ("Player " .. userId)
	names[userId] = name
	return name
end

-- Called by the run service: a player started (or resumed) running with `banked`
-- seconds already on the clock, at unix time `since`.
function Leaderboards.setLive(player: Player, banked: number, since: number)
	localLive[player.UserId] = { userId = player.UserId, name = player.DisplayName, banked = banked, since = since }
end

function Leaderboards.clearLive(player: Player)
	localLive[player.UserId] = nil
	sharedLive[player.UserId] = nil
	local map = liveMap
	if map then
		task.spawn(pcall, function()
			map:RemoveAsync(tostring(player.UserId))
		end)
	end
end

local function liveSeconds(run: LiveRun, now: number): number
	return run.banked + math.max(0, now - run.since)
end

local function syncLive()
	local map = liveMap
	if not map then
		sharedLive = table.clone(localLive)
		return
	end
	for userId, run in localLive do
		pcall(function()
			-- Sort key: banked − since, so a higher key means more time right now.
			map:SetAsync(tostring(userId), { n = run.name, b = run.banked, s = run.since }, Config.liveRefreshSeconds * 4, SORT_OFFSET + run.banked - run.since)
		end)
	end
	local ok, items = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Descending, 50)
	end)
	if ok and items then
		local fresh: { [number]: LiveRun } = {}
		for _, item in items :: { any } do
			local userId = tonumber(item.key)
			local v = item.value
			if userId and type(v) == "table" and type(v.b) == "number" and type(v.s) == "number" then
				fresh[userId] = { userId = userId, name = tostring(v.n), banked = v.b, since = v.s }
			end
		end
		for userId, run in localLive do
			fresh[userId] = run -- our own players are always current
		end
		sharedLive = fresh
	end
end

local function render(lobby: LobbyBuilder.Lobby)
	local now = os.time()

	-- Time board: best times, replaced by the live time when someone is sitting now.
	type Row = { userId: number, seconds: number, live: boolean }
	local rows: { [number]: Row } = {}
	for _, e in topBest do
		rows[e.userId] = { userId = e.userId, seconds = e.value, live = false }
	end
	for userId, run in sharedLive do
		local seconds = liveSeconds(run, now)
		local existing = rows[userId]
		if not existing or seconds >= existing.seconds then
			rows[userId] = { userId = userId, seconds = seconds, live = true }
		end
		names[userId] = names[userId] or run.name
	end
	local sorted: { Row } = {}
	for _, row in rows do
		table.insert(sorted, row)
	end
	table.sort(sorted, function(a, b)
		return a.seconds > b.seconds
	end)

	local board = lobby.timeBoard
	for i, label in board.rows do
		local row = sorted[i]
		if row then
			label.Text = string.format("%2d. %-16s %10s%s", i, string.sub(nameOf(row.userId), 1, 16), Format.duration(row.seconds), if row.live then "  ● LIVE" else "")
		else
			label.Text = if i == 1 then " 1. (nobody yet. be the first to do nothing)" else ""
		end
	end
	local liveCount = 0
	for _ in sharedLive do
		liveCount += 1
	end
	board.footer.Text = string.format("%d doing nothing right now", liveCount)

	local spend = lobby.spendBoard
	for i, label in spend.rows do
		local e = topSpent[i]
		label.Text = if e then string.format("%2d. %-16s %8s R$", i, string.sub(nameOf(e.userId), 1, 16), Format.commas(e.value)) else ""
	end
	spend.footer.Text = "Thank you for supporting the game"
end

function Leaderboards.start(lobby: LobbyBuilder.Lobby)
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap("LiveRuns_v1")
	end)
	if ok then
		liveMap = map
	end

	task.spawn(function()
		while true do
			topBest = Store.top("best", Config.boardSize)
			topSpent = Store.top("spent", Config.boardSize)
			task.wait(Config.boardRefreshSeconds)
		end
	end)
	task.spawn(function()
		while true do
			syncLive()
			task.wait(Config.liveRefreshSeconds)
		end
	end)
	task.spawn(function()
		while true do
			render(lobby)
			task.wait(1)
		end
	end)
end

-- After a purchase or a new best, pull the boards sooner than the minute timer.
function Leaderboards.refreshSoon()
	task.delay(3, function()
		topBest = Store.top("best", Config.boardSize)
		topSpent = Store.top("spent", Config.boardSize)
	end)
end

return Leaderboards
