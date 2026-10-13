--!strict
-- The custom loading screen. Runs from ReplicatedFirst before anything else loads:
-- "Doing Nothing" in grungy letters that slowly droop, a rust tagline, falling dead
-- leaves, a loading bar, a joke "done nothing for" counter and deadpan tips.
-- It stays at least a few seconds, waits for the game to load, then fades out.
-- A Skip button appears after 6 seconds.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BONE = Color3.fromRGB(232, 226, 208)
local MUTED = Color3.fromRGB(184, 176, 154)
local RUST = Color3.fromRGB(201, 69, 44)
local MIN_SECONDS = 4
local SKIP_AFTER = 6

local TIPS = {
	"Tip: rocks have done this for 4 billion years. Show some respect.",
	"Your chair has more willpower than you. Prove it wrong.",
	"Don't touch anything. Not the mouse. Not the keys. Not your hopes.",
	"Distractions are coming. You will fall for them. Probably.",
	"Doing nothing: finally, a skill your family believes you have.",
	"The leaderboard remembers everything. Unlike your goals.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local root = Instance.new("CanvasGroup")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(7, 9, 11)
root.BorderSizePixel = 0
root.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(7, 9, 11)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(20, 27, 31)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 13, 15)),
})
gradient.Parent = root

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

-- Moon
local moon = Instance.new("Frame")
moon.AnchorPoint = Vector2.new(0.5, 0.5)
moon.Position = UDim2.fromScale(0.76, 0.2)
moon.Size = UDim2.fromScale(0.13, 0.13)
moon.BackgroundColor3 = Color3.fromRGB(233, 228, 212)
moon.BorderSizePixel = 0
corner(moon, UDim.new(0.5, 0))
local moonAspect = Instance.new("UIAspectRatioConstraint")
moonAspect.Parent = moon
moon.Parent = root

-- Mountains: two dark bands with soft tops.
for i, color in { Color3.fromRGB(20, 27, 31), Color3.fromRGB(12, 16, 19) } do
	local band = Instance.new("Frame")
	band.AnchorPoint = Vector2.new(0.5, 0)
	band.Position = UDim2.fromScale(0.5, 0.62 + (i - 1) * 0.1)
	band.Size = UDim2.fromScale(1.6, 0.6)
	band.BackgroundColor3 = color
	band.BorderSizePixel = 0
	corner(band, UDim.new(0.5, 0))
	band.Parent = root
end

-- Title letters (each one droops on its own).
local title = Instance.new("Frame")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.32)
title.Size = UDim2.fromScale(0.9, 0.2)
title.BackgroundTransparency = 1
title.Parent = root
local titleLayout = Instance.new("UIListLayout")
titleLayout.FillDirection = Enum.FillDirection.Horizontal
titleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
titleLayout.Parent = title

local letters: { TextLabel } = {}
for i, ch in string.split("Doing Nothing", "") do
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.062, 1)
	holder.LayoutOrder = i
	holder.Parent = title
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.PermanentMarker
	l.TextScaled = true
	l.TextColor3 = BONE
	l.Text = ch
	l.Parent = holder
	table.insert(letters, l)
end

local function text(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.TextScaled = true
	l.Font = Enum.Font.RobotoMono
	l.TextColor3 = BONE
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = root
	return l
end

text({ Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.6, 0.045), Font = Enum.Font.Oswald, TextColor3 = RUST, Text = "THE ONLY GAME YOU WERE BORN TO WIN" })
local status = text({ Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(0.55, 0.032), Text = "Loading. Please do nothing. You're a natural." })

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.65)
barBack.Size = UDim2.fromScale(0.5, 0.012)
barBack.BackgroundColor3 = Color3.fromRGB(34, 41, 45)
barBack.BorderSizePixel = 0
barBack.Parent = root
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = RUST
bar.BorderSizePixel = 0
bar.Parent = barBack

local counter = text({ Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.55, 0.03), TextColor3 = MUTED })
local tip = text({ Position = UDim2.fromScale(0.5, 0.77), Size = UDim2.fromScale(0.62, 0.03) })

local skip = Instance.new("TextButton")
skip.AnchorPoint = Vector2.new(1, 1)
skip.Position = UDim2.new(1, -24, 1, -24)
skip.Size = UDim2.fromOffset(220, 48)
skip.BackgroundTransparency = 1
skip.TextColor3 = BONE
skip.Font = Enum.Font.RobotoMono
skip.TextSize = 18
skip.Text = "SKIP (THE IRONY)"
skip.Visible = false
local skipStroke = Instance.new("UIStroke")
skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
skipStroke.Color = BONE
skipStroke.Transparency = 0.5
skipStroke.Parent = skip
corner(skip, UDim.new(0, 6))
skip.Parent = root

gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Animations ------------------------------------------------------------------------

local alive = true

-- Letters droop one after another, then slowly lift, forever.
for i, l in letters do
	task.delay(i * 0.45, function()
		local info = TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 1.2)
		TweenService:Create(l, info, { Rotation = 9, Position = UDim2.fromScale(0, 0.12) }):Play()
	end)
end

-- Falling dead leaves.
local leafColors = { Color3.fromRGB(138, 47, 31), Color3.fromRGB(74, 48, 32) }
local function spawnLeaf()
	local leaf = Instance.new("Frame")
	leaf.Size = UDim2.fromOffset(math.random(9, 16), math.random(6, 10))
	leaf.Position = UDim2.new(math.random(), 0, 0, -20)
	leaf.BackgroundColor3 = leafColors[math.random(1, #leafColors)]
	leaf.BorderSizePixel = 0
	leaf.Rotation = math.random(0, 360)
	corner(leaf, UDim.new(0.6, 0))
	leaf.Parent = root
	local duration = math.random(9, 15)
	local tween = TweenService:Create(leaf, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Position = UDim2.new(leaf.Position.X.Scale - 0.08, 0, 1.05, 0),
		Rotation = leaf.Rotation + math.random(-400, 400),
	})
	tween.Completed:Connect(function()
		leaf:Destroy()
	end)
	tween:Play()
end
task.spawn(function()
	while alive do
		spawnLeaf()
		task.wait(0.9)
	end
end)

-- Progress, counter and tips.
local started = os.clock()
local maxQueue = math.max(1, ContentProvider.RequestQueueSize)
local skipped = false
skip.Activated:Connect(function()
	skipped = true
end)

local tipIndex = math.random(1, #TIPS)
tip.Text = TIPS[tipIndex]
task.spawn(function()
	while alive do
		task.wait(4)
		tipIndex = tipIndex % #TIPS + 1
		tip.Text = TIPS[tipIndex]
	end
end)

local connection = RunService.RenderStepped:Connect(function()
	local elapsed = os.clock() - started
	local queue = ContentProvider.RequestQueueSize
	maxQueue = math.max(maxQueue, queue)
	local loadedShare = if game:IsLoaded() then 1 else 1 - queue / maxQueue
	local timeShare = math.clamp(elapsed / MIN_SECONDS, 0, 1)
	bar.Size = UDim2.fromScale(math.min(loadedShare, timeShare), 1)
	local s = math.floor(elapsed)
	counter.Text = string.format("You've already done nothing for %d:%02d. Personal best? Sad.", s // 60, s % 60)
	skip.Visible = elapsed >= SKIP_AFTER
end)

-- Leave when loaded and the minimum time has passed, or on Skip.
while not skipped and (not game:IsLoaded() or os.clock() - started < MIN_SECONDS) do
	task.wait(0.1)
end
status.Text = "Loaded. Now go do nothing."
task.wait(if skipped then 0 else 0.6)

alive = false
connection:Disconnect()
local fade = TweenService:Create(root, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
fade:Play()
fade.Completed:Wait()
gui:Destroy()
