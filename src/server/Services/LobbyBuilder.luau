--!strict
-- Builds the night zen garden lobby in code: a stone plaza with spawn, a dark koi pond
-- and stone lantern, two leaderboard gates, a dead tree, a stepping-stone ring, 20
-- private booths (floor, posts, roof, chair, slate screen, lantern, bonsai) with
-- bamboo between them, and an outer ring of dark pines. Night lighting and fog.
--
-- It is rebuilt on every server start, so edit this file (not Studio) to change it.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

export type BoothScreen = {
	header: TextLabel,
	live: TextLabel,
	timer: TextLabel,
	status: TextLabel,
	footer: TextLabel,
}

export type Booth = {
	index: number,
	model: Model,
	seat: Seat,
	cameraPoint: BasePart,
	screen: BoothScreen,
}

export type Board = {
	title: TextLabel,
	rows: { TextLabel },
	footer: TextLabel,
}

export type Lobby = {
	booths: { Booth },
	timeBoard: Board,
	spendBoard: Board,
}

local BONE = Color3.fromRGB(232, 226, 208)
local MUTED = Color3.fromRGB(184, 176, 154)
local RUST = Color3.fromRGB(201, 69, 44)
local SLATE = Color3.fromRGB(11, 14, 16)
local WOOD = Color3.fromRGB(42, 29, 21)
local DARK_WOOD = Color3.fromRGB(18, 12, 8)
local STONE = Color3.fromRGB(46, 52, 55)
local SAND = Color3.fromRGB(28, 33, 36)
local PINE = Color3.fromRGB(22, 38, 27)
local LANTERN = Color3.fromRGB(255, 170, 80)

local BOOTH_RING = 75 -- studs from the centre
local PLAZA_RADIUS = 30

local LobbyBuilder = {}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function cylinder(parent: Instance, cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material?): Part
	-- Cylinders run along X, so turn them upright.
	return part(parent, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function textLabel(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = BONE
	l.Font = Enum.Font.SpecialElite
	l.TextScaled = true
	l.Text = ""
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function surfaceGui(target: BasePart, face: Enum.NormalId, pixelsPerStud: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = target
	return gui
end

local function setupLighting()
	Lighting.ClockTime = 0.3
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(26, 30, 40)
	Lighting.OutdoorAmbient = Color3.fromRGB(52, 58, 72)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.FogColor = Color3.fromRGB(14, 18, 22)
	Lighting.FogStart = 60
	Lighting.FogEnd = 320
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.38
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(70, 80, 95)
		atmosphere.Decay = Color3.fromRGB(20, 24, 30)
		atmosphere.Glare = 0
		atmosphere.Haze = 2
		atmosphere.Parent = Lighting
	end
end

local function buildBoard(parent: Instance, cf: CFrame, titleText: string, subtitle: string): Board
	-- Torii-style frame: two rust pillars, a top beam, and a slate panel facing the plaza.
	local model = Instance.new("Model")
	model.Name = titleText
	model.Parent = parent
	for _, x in { -12, 12 } do
		cylinder(model, cf * CFrame.new(x, 9, 0), 18, 1.6, Color3.fromRGB(122, 42, 31))
	end
	part(model, { Name = "Beam", Size = Vector3.new(30, 1.4, 2), CFrame = cf * CFrame.new(0, 18.6, 0), Color = Color3.fromRGB(122, 42, 31) })
	part(model, { Name = "Beam2", Size = Vector3.new(26, 0.8, 1.4), CFrame = cf * CFrame.new(0, 16.8, 0), Color = Color3.fromRGB(90, 30, 22) })
	local panel = part(model, { Name = "Panel", Size = Vector3.new(22, 14, 0.6), CFrame = cf * CFrame.new(0, 9, 0), Color = SLATE })

	-- The plaza is in front of the board (its Back face points at the plaza).
	local gui = surfaceGui(panel, Enum.NormalId.Back, 40)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = SLATE
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 24)
	padding.PaddingRight = UDim.new(0, 24)
	padding.PaddingTop = UDim.new(0, 16)
	padding.Parent = frame

	local title = textLabel(frame, { Size = UDim2.new(1, 0, 0, 70), Font = Enum.Font.PermanentMarker, Text = titleText, TextColor3 = BONE })
	textLabel(frame, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 68), Text = subtitle, TextColor3 = RUST, Font = Enum.Font.RobotoMono })
	local rows: { TextLabel } = {}
	for i = 1, Config.boardSize do
		table.insert(rows, textLabel(frame, {
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromOffset(0, 104 + (i - 1) * 38),
			Font = Enum.Font.RobotoMono,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if i <= 3 then BONE else MUTED,
			Text = "",
		}))
	end
	local footer = textLabel(frame, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -34), Font = Enum.Font.RobotoMono, TextColor3 = MUTED, Text = "" })
	return { title = title, rows = rows, footer = footer }
end

local function buildBoothScreen(screenPart: BasePart): BoothScreen
	local gui = surfaceGui(screenPart, Enum.NormalId.Back, 60)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = SLATE
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local header = textLabel(frame, { Size = UDim2.new(0.7, 0, 0, 24), Position = UDim2.fromOffset(18, 12), Font = Enum.Font.RobotoMono, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left })
	local live = textLabel(frame, { Size = UDim2.new(0.2, 0, 0, 24), Position = UDim2.new(0.8, -18, 0, 12), Font = Enum.Font.RobotoMono, TextColor3 = Color3.fromRGB(224, 90, 62), TextXAlignment = Enum.TextXAlignment.Right })
	textLabel(frame, { Size = UDim2.new(1, -36, 0, 50), Position = UDim2.fromOffset(18, 44), Font = Enum.Font.PermanentMarker, Text = "Do nothing to win" })
	local timer = textLabel(frame, { Size = UDim2.new(1, -36, 0, 120), Position = UDim2.fromOffset(18, 100), Font = Enum.Font.Oswald, Text = "0:00" })
	local status = textLabel(frame, { Size = UDim2.new(1, -36, 0, 24), Position = UDim2.fromOffset(18, 224), Font = Enum.Font.RobotoMono, TextColor3 = RUST })
	local footer = textLabel(frame, { Size = UDim2.new(1, -36, 0, 22), Position = UDim2.new(0, 18, 1, -36), Font = Enum.Font.RobotoMono, TextColor3 = MUTED })
	return { header = header, live = live, timer = timer, status = status, footer = footer }
end

local function buildBooth(parent: Instance, index: number): Booth
	local angle = math.rad(-90 + (index - 1) * (360 / Config.booths))
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local origin = outward * BOOTH_RING
	-- The booth's forward (-Z) points outward, away from the plaza, toward its screen.
	local cf = CFrame.lookAt(origin, origin + outward)

	local model = Instance.new("Model")
	model.Name = string.format("Booth%02d", index)
	model:SetAttribute("BoothIndex", index)
	model.Parent = parent

	part(model, { Name = "Floor", Size = Vector3.new(14, 1, 14), CFrame = cf * CFrame.new(0, 0.5, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	for _, offset in { Vector3.new(-6.5, 0, -6.5), Vector3.new(6.5, 0, -6.5), Vector3.new(-6.5, 0, 6.5), Vector3.new(6.5, 0, 6.5) } do
		part(model, { Name = "Post", Size = Vector3.new(1, 10, 1), CFrame = cf * CFrame.new(offset + Vector3.new(0, 6, 0)), Color = DARK_WOOD, Material = Enum.Material.Wood })
	end
	part(model, { Name = "Roof", Size = Vector3.new(17, 1, 17), CFrame = cf * CFrame.new(0, 11.5, 0), Color = DARK_WOOD, Material = Enum.Material.Wood })
	part(model, { Name = "RoofTop", Size = Vector3.new(11, 1, 11), CFrame = cf * CFrame.new(0, 12.5, 0), Color = SLATE })

	-- Chair at the back, facing the screen.
	local seat = Instance.new("Seat")
	seat.Name = "Chair"
	seat.Anchored = true
	seat.Size = Vector3.new(3, 1, 3)
	seat.CFrame = cf * CFrame.new(0, 1.8, 2.5)
	seat.Color = Color3.fromRGB(74, 52, 38)
	seat.Material = Enum.Material.Fabric
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = model
	part(model, { Name = "ChairBack", Size = Vector3.new(3, 3, 0.5), CFrame = cf * CFrame.new(0, 3.5, 4.1), Color = Color3.fromRGB(58, 40, 29), Material = Enum.Material.Fabric })

	-- Slate screen at the front, in a wood frame, facing the chair.
	part(model, { Name = "ScreenFrame", Size = Vector3.new(10, 6.4, 0.4), CFrame = cf * CFrame.new(0, 6, -5.6), Color = WOOD, Material = Enum.Material.Wood })
	local screenPart = part(model, { Name = "Screen", Size = Vector3.new(9, 5.5, 0.2), CFrame = cf * CFrame.new(0, 6, -5.35), Color = SLATE })
	local screen = buildBoothScreen(screenPart)

	-- Lantern with a warm light, and a bonsai.
	local lantern = part(model, { Name = "Lantern", Size = Vector3.new(1.4, 2, 1.4), CFrame = cf * CFrame.new(-5, 2, 3), Color = LANTERN, Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = LANTERN
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = lantern
	part(model, { Name = "Pot", Size = Vector3.new(1.6, 1, 1.6), CFrame = cf * CFrame.new(5, 1.5, 3), Color = WOOD })
	part(model, { Name = "Bonsai", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = cf * CFrame.new(5, 3, 3), Color = PINE, Material = Enum.Material.Grass })

	-- Where the camera sits while the player is seated: behind the chair, looking at the screen.
	local camPos = (cf * CFrame.new(0, 5.4, 5.5)).Position
	local screenPos = screenPart.Position
	local cameraPoint = part(model, {
		Name = "CameraPoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.lookAt(camPos, screenPos),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})

	return { index = index, model = model, seat = seat, cameraPoint = cameraPoint, screen = screen }
end

local function buildGarden(parent: Instance)
	local rng = Random.new(42)

	part(parent, { Name = "Ground", Size = Vector3.new(260, 2, 260), CFrame = CFrame.new(0, -1, 0), Color = SAND, Material = Enum.Material.Sand })
	cylinder(parent, CFrame.new(0, 0.25, 0), 0.5, PLAZA_RADIUS * 2, STONE, Enum.Material.Slate)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.6, 6)
	spawn.Color = RUST
	spawn.Material = Enum.Material.Slate
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = parent

	-- Black koi pond and a stone lantern beside spawn.
	cylinder(parent, CFrame.new(-12, 0.55, 12), 0.2, 14, Color3.fromRGB(5, 8, 10), Enum.Material.Glass)
	part(parent, { Name = "StoneLanternBase", Size = Vector3.new(2.5, 3, 2.5), CFrame = CFrame.new(12, 2, 12), Color = Color3.fromRGB(74, 70, 64), Material = Enum.Material.Slate })
	local glow = part(parent, { Name = "StoneLanternLight", Size = Vector3.new(2, 1.6, 2), CFrame = CFrame.new(12, 4.3, 12), Color = LANTERN, Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = LANTERN
	light.Brightness = 1.5
	light.Range = 22
	light.Parent = glow
	part(parent, { Name = "StoneLanternCap", Size = Vector3.new(3.4, 0.8, 3.4), CFrame = CFrame.new(12, 5.5, 12), Color = Color3.fromRGB(74, 70, 64), Material = Enum.Material.Slate })

	-- Dead tree with its last red leaves, dropping them slowly.
	local trunk = cylinder(parent, CFrame.new(26, 7, -14), 14, 2.2, Color3.fromRGB(8, 8, 9), Enum.Material.Wood)
	for _, branch in { { 8, 30, 3.5 }, { 10, -35, 4 }, { 12, 20, -2 } } do
		part(parent, {
			Name = "Branch",
			Size = Vector3.new(0.8, 7, 0.8),
			CFrame = CFrame.new(26, branch[1], -14) * CFrame.Angles(math.rad(branch[3] * 6), 0, math.rad(branch[2])) * CFrame.new(0, 3, 0),
			Color = Color3.fromRGB(8, 8, 9),
			Material = Enum.Material.Wood,
		})
	end
	local leaves = Instance.new("ParticleEmitter")
	leaves.Color = ColorSequence.new(Color3.fromRGB(138, 47, 31))
	leaves.Size = NumberSequence.new(0.35)
	leaves.Rate = 1.5
	leaves.Lifetime = NumberRange.new(6, 9)
	leaves.Speed = NumberRange.new(1, 2)
	leaves.Acceleration = Vector3.new(0.6, -1.2, 0)
	leaves.RotSpeed = NumberRange.new(-60, 60)
	leaves.Rotation = NumberRange.new(0, 360)
	leaves.SpreadAngle = Vector2.new(180, 180)
	leaves.Parent = trunk

	-- Fireflies drifting over the plaza.
	local fireflyEmitter = part(parent, { Name = "Fireflies", Size = Vector3.new(60, 1, 60), CFrame = CFrame.new(0, 4, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local fireflies = Instance.new("ParticleEmitter")
	fireflies.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	fireflies.LightEmission = 1
	fireflies.Size = NumberSequence.new(0.18)
	fireflies.Rate = 3
	fireflies.Lifetime = NumberRange.new(5, 8)
	fireflies.Speed = NumberRange.new(0.3, 0.8)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
	fireflies.Parent = fireflyEmitter

	-- Stepping-stone ring from the plaza to the booths.
	for i = 0, 47 do
		local a = math.rad(i * 7.5)
		local r = 55 + rng:NextNumber(-1, 1)
		cylinder(parent, CFrame.new(math.cos(a) * r, 0.15, math.sin(a) * r), 0.3, rng:NextNumber(3.2, 4.2), Color3.fromRGB(58, 66, 70), Enum.Material.Slate)
	end
	-- Spokes of stones from the plaza edge to the ring, every 90 degrees.
	for spoke = 0, 3 do
		local a = math.rad(spoke * 90 + 45)
		for step = 0, 5 do
			local r = PLAZA_RADIUS + 3 + step * 4
			cylinder(parent, CFrame.new(math.cos(a) * r, 0.15, math.sin(a) * r), 0.3, 3.4, Color3.fromRGB(58, 66, 70), Enum.Material.Slate)
		end
	end

	-- Bamboo between booths for privacy.
	for i = 0, Config.booths - 1 do
		local a = math.rad(-90 + (i + 0.5) * (360 / Config.booths))
		local base = Vector3.new(math.cos(a), 0, math.sin(a)) * BOOTH_RING
		for _ = 1, 4 do
			local offset = Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6))
			local height = rng:NextNumber(12, 18)
			cylinder(parent, CFrame.new(base + offset + Vector3.new(0, height / 2, 0)), height, 0.6, Color3.fromRGB(31, 51, 34), Enum.Material.Grass)
		end
	end

	-- Outer ring of dark pines.
	for i = 0, 23 do
		local a = math.rad(i * 15 + 7)
		local r = 108 + rng:NextNumber(-4, 4)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local h = rng:NextNumber(16, 24)
		cylinder(parent, CFrame.new(p + Vector3.new(0, h / 2, 0)), h, 1.6, Color3.fromRGB(14, 12, 10), Enum.Material.Wood)
		for layer = 0, 2 do
			local size = 12 - layer * 3
			part(parent, {
				Name = "Pine",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size * 0.6, size),
				CFrame = CFrame.new(p + Vector3.new(0, h * 0.55 + layer * 3.5, 0)),
				Color = PINE,
				Material = Enum.Material.Grass,
			})
		end
	end
end

function LobbyBuilder.build(): Lobby
	setupLighting()

	local existing = Workspace:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	buildGarden(lobby)
	-- North side (−Z) faces the spawn: boards look back toward the plaza.
	local timeBoard = buildBoard(lobby, CFrame.new(-14, 0, -22), "Longest time doing nothing", "ALL SERVERS · LIVE")
	local spendBoard = buildBoard(lobby, CFrame.new(14, 0, -22), "Top supporters", "ROBUX SPENT ON CONTINUES")

	local booths: { Booth } = {}
	local boothFolder = Instance.new("Folder")
	boothFolder.Name = "Booths"
	boothFolder.Parent = lobby
	for i = 1, Config.booths do
		table.insert(booths, buildBooth(boothFolder, i))
	end

	lobby.Parent = Workspace
	return { booths = booths, timeBoard = timeBoard, spendBoard = spendBoard }
end

return LobbyBuilder
