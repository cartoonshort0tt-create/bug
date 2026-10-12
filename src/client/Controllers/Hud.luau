--!strict
-- The HUD, built in code for the prototype: coins and bag (top left), weather and
-- forecast (top centre), toasts, the timing ring, and a big thumb-zone Swing button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Format)
local WeatherClock = require(ReplicatedStorage.Shared.WeatherClock)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local player = Players.LocalPlayer

local INK = Color3.fromRGB(27, 42, 30)
local PANEL = Color3.fromRGB(255, 255, 255)
local ACCENT = Color3.fromRGB(44, 122, 75)

export type Hud = {
	gui: ScreenGui,
	swingButton: TextButton,
	ring: Frame,
	ringCircle: Frame,
	ringGreen: Frame,
	ringHole: Frame,
	ringPerfect: Frame,
	toast: (self: Hud, text: string, color: Color3?) -> (),
}

local Hud = {}

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function label(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextColor3 = INK
	l.Font = Enum.Font.FredokaOne
	l.TextSize = textSize
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

local function circle(parent: Instance, name: string, color: Color3, transparency: number, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.ZIndex = z
	corner(f, UDim.new(0.5, 0))
	f.Parent = parent
	return f
end

function Hud.new(): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Top left: coins, bag, net.
	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.Size = UDim2.fromOffset(230, 92)
	stats.Position = UDim2.fromOffset(12, 12)
	stats.BackgroundColor3 = PANEL
	stats.BackgroundTransparency = 0.1
	corner(stats, UDim.new(0, 14))
	stats.Parent = gui
	local coins = label(stats, "Coins", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 6), 28)
	local bag = label(stats, "Bag", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 40), 18)
	local net = label(stats, "Net", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 62), 16)

	-- Top centre: weather now and next.
	local weather = Instance.new("Frame")
	weather.Name = "Weather"
	weather.AnchorPoint = Vector2.new(0.5, 0)
	weather.Size = UDim2.fromOffset(300, 60)
	weather.Position = UDim2.new(0.5, 0, 0, 12)
	weather.BackgroundColor3 = PANEL
	weather.BackgroundTransparency = 0.1
	corner(weather, UDim.new(0, 14))
	weather.Parent = gui
	local weatherNow = label(weather, "Now", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 4), 22)
	weatherNow.TextXAlignment = Enum.TextXAlignment.Center
	local weatherNext = label(weather, "Next", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 34), 15)
	weatherNext.TextXAlignment = Enum.TextXAlignment.Center
	weatherNext.Font = Enum.Font.GothamMedium

	-- Toasts stack above the bottom of the screen.
	local toasts = Instance.new("Frame")
	toasts.Name = "Toasts"
	toasts.AnchorPoint = Vector2.new(0.5, 1)
	toasts.Size = UDim2.fromOffset(420, 200)
	toasts.Position = UDim2.new(0.5, 0, 1, -24)
	toasts.BackgroundTransparency = 1
	toasts.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = toasts

	-- The timing ring: a shrinking white circle over a green band.
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Size = UDim2.fromOffset(220, 220)
	ring.Position = UDim2.fromScale(0.5, 0.55)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.Parent = gui
	local backdrop = circle(ring, "Backdrop", Color3.fromRGB(0, 0, 0), 0.65, 1)
	backdrop.Size = UDim2.fromScale(1, 1)
	local ringGreen = circle(ring, "Green", Color3.fromRGB(92, 200, 135), 0.15, 2)
	local ringHole = circle(ring, "Hole", Color3.fromRGB(20, 32, 24), 0.2, 3)
	local ringPerfect = circle(ring, "Perfect", Color3.fromRGB(0, 0, 0), 1, 4)
	local perfectStroke = Instance.new("UIStroke")
	perfectStroke.Color = Color3.fromRGB(240, 194, 74)
	perfectStroke.Thickness = 3
	perfectStroke.Parent = ringPerfect
	local ringCircle = circle(ring, "Shrinking", Color3.fromRGB(0, 0, 0), 1, 5)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 5
	stroke.Parent = ringCircle

	-- Bottom right: the thumb-zone Swing button.
	local swingButton = Instance.new("TextButton")
	swingButton.Name = "Swing"
	swingButton.AnchorPoint = Vector2.new(1, 1)
	swingButton.Size = UDim2.fromOffset(150, 150)
	swingButton.Position = UDim2.new(1, -24, 1, -24)
	swingButton.BackgroundColor3 = ACCENT
	swingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	swingButton.Font = Enum.Font.FredokaOne
	swingButton.TextSize = 32
	swingButton.Text = "SWING"
	swingButton.AutoButtonColor = true
	corner(swingButton, UDim.new(0.5, 0))
	swingButton.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")

	local toastOrder = 0
	local hud = {
		gui = gui,
		swingButton = swingButton,
		ring = ring,
		ringCircle = ringCircle,
		ringGreen = ringGreen,
		ringHole = ringHole,
		ringPerfect = ringPerfect,
	} :: any

	function hud.toast(_self: Hud, text: string, color: Color3?)
		toastOrder += 1
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromOffset(400, 40)
		t.BackgroundColor3 = color or INK
		t.BackgroundTransparency = 0.05
		t.TextColor3 = Color3.fromRGB(255, 255, 255)
		t.Font = Enum.Font.FredokaOne
		t.TextSize = 20
		t.TextWrapped = true
		t.Text = text
		t.LayoutOrder = toastOrder
		corner(t, UDim.new(0, 12))
		t.Parent = toasts
		task.delay(3, function()
			t:Destroy()
		end)
	end

	-- Refresh stats from replicated attributes, and the weather every second.
	local function refreshStats()
		coins.Text = Format.commas((player:GetAttribute("Coins") or 0) :: number) .. " coins"
		bag.Text = string.format("Bag %d / %d", (player:GetAttribute("BagCount") or 0) :: number, (player:GetAttribute("BagSize") or 0) :: number)
		net.Text = tostring(player:GetAttribute("NetName") or "")
	end
	player.AttributeChanged:Connect(refreshStats)
	refreshStats()

	local lastWeatherUpdate = 0
	RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		if clock - lastWeatherUpdate < 1 then
			return
		end
		lastWeatherUpdate = clock
		local zoneId = (player:GetAttribute("Zone") or "Meadow") :: string
		local t = Workspace:GetServerTimeNow()
		local state = WeatherClock.stateAt(zoneId, t)
		local nowText = state.weather
		if state.eclipse then
			nowText = "Eclipse!"
		elseif state.rainbow then
			nowText = "Rainbow!"
		end
		weatherNow.Text = string.format("%s · %s · %s", nowText, state.phase, Format.clock(state.windowEndsAt - t))
		local nextItem = WeatherClock.nextSpecial(zoneId, t, 72)
		if nextItem then
			weatherNext.Text = string.format("%s next: %s in %s", Zones.ById[zoneId].name, nextItem.weather, Format.clock(nextItem.startsAt - t))
		else
			weatherNext.Text = Zones.ById[zoneId].name
		end
	end)

	return hud :: Hud
end

return Hud
