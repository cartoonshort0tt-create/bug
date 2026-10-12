--!strict
-- Client-only bug presentation: gentle bobbing, name tags for Rare and above, and
-- hiding other players' personal bugs. The server never moves bugs, so changing
-- their CFrame locally is safe and costs no network traffic.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local BugVisuals = {}

type Tracked = { part: BasePart, base: CFrame, phase: number, speed: number }

function BugVisuals.start()
	local bugsFolder = Workspace:WaitForChild("Bugs")
	local tracked: { [BasePart]: Tracked } = {}

	local function add(child: Instance)
		if not child:IsA("BasePart") then
			return
		end
		local owner = child:GetAttribute("OwnerUserId")
		if owner ~= nil and owner ~= player.UserId then
			child.LocalTransparencyModifier = 1
			return
		end
		tracked[child] = {
			part = child,
			base = child.CFrame,
			phase = math.random() * math.pi * 2,
			speed = 1.5 + math.random(),
		}
		local tier = child:GetAttribute("Tier")
		if tier ~= "Common" then
			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromOffset(160, 26)
			tag.StudsOffset = Vector3.new(0, 2.2, 0)
			tag.MaxDistance = 45
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.TextColor3 = Color3.fromRGB(255, 255, 255)
			text.TextStrokeTransparency = 0.3
			text.Font = Enum.Font.FredokaOne
			text.TextScaled = true
			text.Text = string.format("%s · %s", child.Name, tostring(tier))
			text.Parent = tag
			tag.Parent = child
		end
	end

	bugsFolder.ChildAdded:Connect(add)
	bugsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			tracked[child] = nil
		end
	end)
	for _, child in bugsFolder:GetChildren() do
		add(child)
	end

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for part, info in tracked do
			local y = math.sin(t * info.speed + info.phase) * 0.6
			part.CFrame = info.base * CFrame.new(0, y, 0)
		end
	end)
end

return BugVisuals
