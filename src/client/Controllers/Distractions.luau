--!strict
-- Distractions while running: sticky notes with fake instructions, a fly, a cat, a
-- "DO NOT PRESS" button, flickering lights, sounds and banners. They are tricks in the
-- game's own style: never a copy of Roblox's interface, never about Robux, and they
-- vanish the moment the run ends (so the lost screen is always calm).
-- Timed ones come from Config.distractions (`at` seconds); the rest play at random.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Distractions = {}

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

function Distractions.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Distractions"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local active: { Instance } = {}
	local runToken = 0
	local baseBrightness = Lighting.Brightness

	local function clear()
		runToken += 1
		for _, inst in active do
			inst:Destroy()
		end
		table.clear(active)
		Lighting.Brightness = baseBrightness
	end

	local function keep(inst: Instance, seconds: number, token: number)
		table.insert(active, inst)
		task.delay(seconds, function()
			if token == runToken then
				local i = table.find(active, inst)
				if i then
					table.remove(active, i)
				end
			end
			inst:Destroy()
		end)
	end

	local function randomSpot(): UDim2
		return UDim2.fromScale(0.1 + math.random() * 0.7, 0.12 + math.random() * 0.6)
	end

	local show: { [string]: (d: Config.Distraction, token: number) -> () } = {
		note = function(d, token)
			local note = Instance.new("TextLabel")
			note.Size = UDim2.fromOffset(280, 130)
			note.Position = randomSpot()
			note.Rotation = math.random(-7, 7)
			note.BackgroundColor3 = Color3.fromRGB(217, 207, 178)
			note.TextColor3 = Color3.fromRGB(26, 20, 16)
			note.Font = Enum.Font.PermanentMarker
			note.TextScaled = true
			note.TextWrapped = true
			note.Text = d.text or ""
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 14)
			pad.Parent = note
			note.Parent = gui
			TweenService:Create(note, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = note.Rotation + 4 }):Play()
			keep(note, d.duration, token)
		end,
		fly = function(d, token)
			local fly = Instance.new("Frame")
			fly.Size = UDim2.fromOffset(22, 14)
			fly.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			fly.Position = randomSpot()
			corner(fly, 7)
			fly.Parent = gui
			keep(fly, d.duration, token)
			task.spawn(function()
				local stop = os.clock() + d.duration
				while os.clock() < stop and fly.Parent and token == runToken do
					TweenService:Create(fly, TweenInfo.new(0.4, Enum.EasingStyle.Sine), { Position = randomSpot() }):Play()
					task.wait(0.45)
				end
			end)
		end,
		cat = function(d, token)
			local cat = Instance.new("TextLabel")
			cat.BackgroundTransparency = 1
			cat.Size = UDim2.fromOffset(260, 120)
			cat.Position = UDim2.new(-0.25, 0, 0.62, 0)
			cat.Font = Enum.Font.RobotoMono
			cat.TextScaled = true
			cat.TextColor3 = Color3.fromRGB(232, 226, 208)
			cat.TextStrokeTransparency = 0.2
			cat.Text = " /\\_/\\\n( o.o )  ...\n > ^ <"
			cat.Parent = gui
			keep(cat, d.duration, token)
			local walk = TweenService:Create(cat, TweenInfo.new(d.duration * 0.45, Enum.EasingStyle.Linear), { Position = UDim2.new(0.4, 0, 0.62, 0) })
			walk:Play()
			walk.Completed:Connect(function()
				if cat.Parent then
					cat.Text = " /\\_/\\\n( O.O )  stare\n > ^ <"
				end
			end)
		end,
		button = function(d, token)
			local b = Instance.new("TextButton")
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Position = UDim2.fromScale(0.5, 0.78)
			b.Size = UDim2.fromOffset(260, 90)
			b.BackgroundColor3 = Color3.fromRGB(176, 40, 28)
			b.TextColor3 = Color3.fromRGB(255, 240, 230)
			b.Font = Enum.Font.Oswald
			b.TextScaled = true
			b.Text = d.text or "DO NOT PRESS"
			corner(b, 45)
			b.Parent = gui
			TweenService:Create(b, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromOffset(285, 98) }):Play()
			keep(b, d.duration, token) -- pressing it is input, so the run ends anyway
		end,
		lights = function(d, token)
			task.spawn(function()
				local stop = os.clock() + d.duration
				while os.clock() < stop and token == runToken do
					Lighting.Brightness = if math.random() < 0.5 then 0 else baseBrightness
					task.wait(0.08 + math.random() * 0.4)
				end
				Lighting.Brightness = baseBrightness
			end)
		end,
		sound = function(d, token)
			if d.soundId and d.soundId ~= "" then
				local sound = Instance.new("Sound")
				sound.SoundId = d.soundId
				sound.Volume = 0.8
				sound.Parent = SoundService
				sound:Play()
				keep(sound, d.duration, token)
			end
			local caption = Instance.new("TextLabel")
			caption.BackgroundTransparency = 1
			caption.AnchorPoint = Vector2.new(0.5, 1)
			caption.Position = UDim2.new(0.5, 0, 1, -40)
			caption.Size = UDim2.new(0.5, 0, 0, 34)
			caption.Font = Enum.Font.SpecialElite
			caption.TextScaled = true
			caption.TextColor3 = Color3.fromRGB(232, 226, 208)
			caption.TextStrokeTransparency = 0.3
			caption.Text = d.text or ""
			caption.Parent = gui
			keep(caption, d.duration, token)
		end,
		banner = function(d, token)
			local banner = Instance.new("TextLabel")
			banner.AnchorPoint = Vector2.new(0.5, 0)
			banner.Position = UDim2.new(0.5, 0, 0, 120)
			banner.Size = UDim2.new(0.8, 0, 0, 70)
			banner.BackgroundColor3 = Color3.fromRGB(11, 14, 16)
			banner.BackgroundTransparency = 0.15
			banner.TextColor3 = Color3.fromRGB(224, 90, 62)
			banner.Font = Enum.Font.PermanentMarker
			banner.TextScaled = true
			banner.Text = d.text or ""
			corner(banner, 6)
			banner.Parent = gui
			keep(banner, d.duration, token)
		end,
	}

	local function play(d: Config.Distraction, token: number)
		if token ~= runToken then
			return
		end
		local fn = show[d.kind]
		if fn then
			fn(d, token)
		end
	end

	local timed: { Config.Distraction } = {}
	local random: { Config.Distraction } = {}
	for _, d in Config.distractions do
		table.insert(if d.at then timed else random, d)
	end

	local function startRun()
		clear()
		local token = runToken
		local startedAt = player:GetAttribute("RunStartedAt")
		local offset = player:GetAttribute("RunOffset")
		if type(startedAt) ~= "number" or type(offset) ~= "number" then
			return
		end
		-- Timed distractions are by total time on the clock, so a Continue skips the
		-- ones already survived.
		for _, d in timed do
			local wait = (d.at :: number) - offset - (Workspace:GetServerTimeNow() - startedAt)
			if wait >= 0 then
				task.delay(wait, play, d, token)
			end
		end
		task.spawn(function()
			while token == runToken and #random > 0 do
				task.wait(math.random(Config.randomDistractionEvery[1], Config.randomDistractionEvery[2]))
				play(random[math.random(1, #random)], token)
			end
		end)
	end

	player:GetAttributeChangedSignal("RunPhase"):Connect(function()
		if player:GetAttribute("RunPhase") == "running" then
			startRun()
		else
			clear()
		end
	end)
end

return Distractions
