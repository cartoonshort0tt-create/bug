--!strict
-- The on-screen HUD in the dark deadpan style:
--   * in the garden: a hint to find a booth
--   * countdown: big "HANDS OFF" with the number
--   * running: a small LIVE tag (the booth screen is the real display)
--   * lost: the "You moved." panel with Continue (price shown) and Restart. No timer
--     pushes the choice; it waits as long as the player likes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local BONE = Color3.fromRGB(232, 226, 208)
local MUTED = Color3.fromRGB(184, 176, 154)
local RUST = Color3.fromRGB(224, 90, 62)
local PANEL = Color3.fromRGB(18, 23, 26)
local INK = Color3.fromRGB(11, 14, 16)

local LOST_LINES = {
	"One twitch. That's all it took. The bonsai is disappointed in you.",
	"You had one job. It was nothing. You failed at nothing.",
	"The crow saw that. The crow tells everyone.",
	"Impressive. Most people can't fail at doing nothing.",
	"Your chair is filing a complaint.",
}

local Hud = {}

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = BONE
	l.Font = Enum.Font.RobotoMono
	l.TextScaled = true
	l.Text = ""
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent: Instance, primary: boolean): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = if primary then BONE else PANEL
	b.TextColor3 = if primary then INK else BONE
	b.Font = Enum.Font.RobotoMono
	b.TextScaled = true
	b.Size = UDim2.new(0.48, 0, 0, 72)
	corner(b, 8)
	if not primary then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = BONE
		stroke.Thickness = 2
		stroke.Parent = b
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = b
	b.Parent = parent
	return b
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Garden hint
	local hint = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0.6, 0, 0, 30),
		Text = "Find a free booth. Sit. Do nothing.",
		TextStrokeTransparency = 0.4,
	})

	-- Countdown
	local countdown = Instance.new("Frame")
	countdown.AnchorPoint = Vector2.new(0.5, 0.5)
	countdown.Position = UDim2.fromScale(0.5, 0.42)
	countdown.Size = UDim2.fromScale(0.6, 0.34)
	countdown.BackgroundTransparency = 1
	countdown.Visible = false
	countdown.Parent = gui
	label(countdown, { Size = UDim2.fromScale(1, 0.3), Font = Enum.Font.PermanentMarker, TextColor3 = RUST, Text = "HANDS OFF", TextStrokeTransparency = 0.3 })
	local countNumber = label(countdown, { Position = UDim2.fromScale(0, 0.28), Size = UDim2.fromScale(1, 0.5), Font = Enum.Font.Oswald, TextStrokeTransparency = 0.3 })
	label(countdown, { Position = UDim2.fromScale(0, 0.8), Size = UDim2.fromScale(1, 0.14), Text = "Don't touch anything. Not even the mouse.", TextStrokeTransparency = 0.3 })

	-- LIVE tag while running
	local live = label(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 64),
		Size = UDim2.fromOffset(140, 26),
		TextColor3 = RUST,
		Text = "● LIVE",
		TextStrokeTransparency = 0.4,
		Visible = false,
	})

	-- Lost panel
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.Visible = false
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.5, 0.78)
	panel.BackgroundColor3 = PANEL
	corner(panel, 10)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(44, 52, 56)
	panelStroke.Parent = panel
	local aspect = Instance.new("UISizeConstraint")
	aspect.MinSize = Vector2.new(320, 360)
	aspect.MaxSize = Vector2.new(640, 600)
	aspect.Parent = panel
	panel.Parent = shade

	label(panel, { Position = UDim2.fromScale(0.05, 0.05), Size = UDim2.fromScale(0.9, 0.17), Font = Enum.Font.PermanentMarker, TextColor3 = RUST, Text = "You moved." })
	local joke = label(panel, { Position = UDim2.fromScale(0.08, 0.23), Size = UDim2.fromScale(0.84, 0.07), TextColor3 = MUTED, TextWrapped = true })
	label(panel, { Position = UDim2.fromScale(0.1, 0.33), Size = UDim2.fromScale(0.8, 0.04), TextColor3 = MUTED, Text = "YOU DID ABSOLUTELY NOTHING FOR" })
	local lostTime = label(panel, { Position = UDim2.fromScale(0.1, 0.38), Size = UDim2.fromScale(0.8, 0.2), Font = Enum.Font.Oswald })
	local bestLine = label(panel, { Position = UDim2.fromScale(0.1, 0.59), Size = UDim2.fromScale(0.8, 0.04), TextColor3 = Color3.fromRGB(143, 208, 162) })

	local buttons = Instance.new("Frame")
	buttons.Position = UDim2.fromScale(0.05, 0.67)
	buttons.Size = UDim2.new(0.9, 0, 0, 72)
	buttons.BackgroundTransparency = 1
	buttons.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.04, 0)
	layout.Parent = buttons
	local continueButton = button(buttons, true)
	local restartButton = button(buttons, false)
	local footnote = label(panel, { Position = UDim2.fromScale(0.07, 0.85), Size = UDim2.fromScale(0.86, 0.1), TextColor3 = MUTED, TextWrapped = true })

	gui.Parent = player:WaitForChild("PlayerGui")

	local ContinueRemote = Remotes.get("Continue")
	local RestartRemote = Remotes.get("Restart")
	continueButton.Activated:Connect(function()
		ContinueRemote:FireServer()
	end)
	restartButton.Activated:Connect(function()
		RestartRemote:FireServer()
	end)

	local lastPhase: string? = nil
	local function refresh()
		local phase = player:GetAttribute("RunPhase")
		local seated = player:GetAttribute("BoothIndex") ~= nil
		hint.Visible = not seated and phase ~= "lost"
		countdown.Visible = phase == "countdown"
		live.Visible = phase == "running"
		shade.Visible = phase == "lost"

		if phase == "lost" then
			if lastPhase ~= "lost" then
				joke.Text = LOST_LINES[math.random(1, #LOST_LINES)]
			end
			local t = (player:GetAttribute("RunLostTime") or 0) :: number
			lostTime.Text = Format.duration(t)
			local best = (player:GetAttribute("Best") or 0) :: number
			bestLine.Text = if t >= best and t > 0 then "New best. Saved to the leaderboard." else "Your best: " .. Format.duration(best)
			local ready = player:GetAttribute("RunContinueReady") == true
			local price = player:GetAttribute("NextContinuePrice")
			continueButton.Visible = not ready and type(price) == "number"
			continueButton.Text = string.format("CONTINUE FROM %s · %s Robux", Format.duration(t), Format.commas((price or 0) :: number))
			restartButton.Text = "RESTART FROM 0:00 · free"
			footnote.Text = if ready
				then "Continue ready. Sit in a booth to pick up from " .. Format.duration(t) .. "."
				else "Continue price this run: 25 → 50 → 100 → 200… It doubles each continue and resets to 25 when you restart. No rush. This screen will wait. It's good at that."
		end
		lastPhase = phase
	end

	for _, name in { "RunPhase", "BoothIndex", "RunLostTime", "Best", "RunContinueReady", "NextContinuePrice" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	RunService.RenderStepped:Connect(function()
		if countdown.Visible then
			local endsAt = player:GetAttribute("RunCountdownEndsAt")
			if type(endsAt) == "number" then
				countNumber.Text = tostring(math.max(1, math.ceil(endsAt - Workspace:GetServerTimeNow())))
			end
		end
	end)

	Remotes.get("Notify").OnClientEvent:Connect(function(message: string)
		hint.Text = message
		hint.Visible = true
		task.delay(5, function()
			if hint.Text == message then
				hint.Text = "Find a free booth. Sit. Do nothing."
				refresh()
			end
		end)
	end)
end

return Hud
