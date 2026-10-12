--!strict
-- Builds a greybox Sunny Meadow for the prototype if the place doesn't already
-- have one. Once you build the real Meadow in Studio, keep these names and the
-- services will use your parts instead:
--   Workspace.Meadow.SellPad, Workspace.Meadow.NetShop, Workspace.Meadow.ForestGate
-- (each needs a ProximityPrompt child, or one is added for you).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)

export type World = {
	meadow: Folder,
	sellPad: BasePart,
	netShop: BasePart,
	forestGate: BasePart,
	bugs: Folder,
}

local WorldService = {}

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function sign(parentPart: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, parentPart.Size.Y / 2 + 3, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(74, 50, 33)
	label.BackgroundTransparency = 0.1
	label.TextColor3 = Color3.fromRGB(255, 244, 220)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = parentPart
end

local function ensurePrompt(target: BasePart, action: string, object: string): ProximityPrompt
	local p = target:FindFirstChildOfClass("ProximityPrompt")
	if not p then
		local created = Instance.new("ProximityPrompt")
		created.Parent = target
		p = created
	end
	assert(p)
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	return p
end

local function buildGreybox(): Folder
	local area = (Zones.ById.Meadow.area :: Zones.Area)
	local meadow = Instance.new("Folder")
	meadow.Name = "Meadow"

	part({
		Name = "Ground",
		Size = Vector3.new(area.sizeX + 60, 2, area.sizeZ + 80),
		Position = Vector3.new(area.x, 0, area.z),
		Color = Color3.fromRGB(124, 186, 86),
		Material = Enum.Material.Grass,
	}, meadow)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(area.x, 1.5, area.z + area.sizeZ / 2 + 15)
	spawn.Color = Color3.fromRGB(154, 106, 58)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = meadow

	-- Dirt path from spawn to the Forest gate.
	part({
		Name = "Path",
		Size = Vector3.new(14, 0.2, area.sizeZ + 60),
		Position = Vector3.new(area.x, 1.1, area.z),
		Color = Color3.fromRGB(226, 197, 143),
		Material = Enum.Material.Ground,
		CanCollide = false,
	}, meadow)

	local sellPad = part({
		Name = "SellPad",
		Size = Vector3.new(10, 1, 10),
		Position = Vector3.new(area.x - 30, 1.5, area.z + area.sizeZ / 2),
		Color = Color3.fromRGB(233, 194, 58),
		Material = Enum.Material.SmoothPlastic,
	}, meadow)
	sign(sellPad, "Sell Stand")

	local netShop = part({
		Name = "NetShop",
		Size = Vector3.new(10, 6, 6),
		Position = Vector3.new(area.x + 30, 4, area.z + area.sizeZ / 2),
		Color = Color3.fromRGB(154, 106, 58),
		Material = Enum.Material.WoodPlanks,
	}, meadow)
	sign(netShop, "Net Shop")

	local forestGate = part({
		Name = "ForestGate",
		Size = Vector3.new(18, 16, 2),
		Position = Vector3.new(area.x, 9, area.z - area.sizeZ / 2 - 10),
		Color = Color3.fromRGB(47, 122, 75),
		Material = Enum.Material.SmoothPlastic,
	}, meadow)
	sign(forestGate, "Whispering Forest")

	-- A few flower patches for the bugs to sit around.
	local colors = {
		Color3.fromRGB(242, 201, 76),
		Color3.fromRGB(242, 143, 176),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(181, 140, 244),
	}
	local rng = Random.new(7)
	for i = 1, 40 do
		part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			Position = Vector3.new(
				area.x + rng:NextNumber(-area.sizeX / 2, area.sizeX / 2),
				1.6,
				area.z + rng:NextNumber(-area.sizeZ / 2, area.sizeZ / 2)
			),
			Color = colors[(i % #colors) + 1],
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}, meadow)
	end

	meadow.Parent = Workspace
	return meadow
end

function WorldService.build(): World
	local existing = Workspace:FindFirstChild("Meadow")
	local meadow: Folder = if existing and existing:IsA("Folder") then existing else buildGreybox()

	local function find(name: string): BasePart
		local p = meadow:FindFirstChild(name, true)
		assert(p and p:IsA("BasePart"), "Workspace.Meadow is missing a part named " .. name)
		return p
	end

	local sellPad = find("SellPad")
	local netShop = find("NetShop")
	local forestGate = find("ForestGate")
	ensurePrompt(sellPad, "Sell bag", "Sell Stand")
	ensurePrompt(netShop, "Buy next net", "Net Shop")
	ensurePrompt(forestGate, "Unlock", Zones.ById.Forest.name)

	local bugs = Workspace:FindFirstChild("Bugs")
	if not bugs then
		bugs = Instance.new("Folder")
		bugs.Name = "Bugs"
		bugs.Parent = Workspace
	end

	return {
		meadow = meadow,
		sellPad = sellPad,
		netShop = netShop,
		forestGate = forestGate,
		bugs = bugs :: Folder,
	}
end

return WorldService
