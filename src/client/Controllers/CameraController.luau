--!strict
-- While the player is in a booth, the camera sits behind the chair looking at the
-- booth's slate screen. Back in the garden, normal camera control returns.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local CameraController = {}

local function cameraPointFor(index: number): BasePart?
	local lobby = Workspace:FindFirstChild("Lobby")
	local booths = lobby and lobby:FindFirstChild("Booths")
	local booth = booths and booths:FindFirstChild(string.format("Booth%02d", index))
	local point = booth and booth:FindFirstChild("CameraPoint")
	return if point and point:IsA("BasePart") then point else nil
end

function CameraController.start()
	local current: number? = nil

	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local index = player:GetAttribute("BoothIndex")
		if type(index) == "number" then
			if current == index then
				return
			end
			local point = cameraPointFor(index)
			if not point then
				return
			end
			current = index
			camera.CameraType = Enum.CameraType.Scriptable
			TweenService:Create(camera, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = point.CFrame }):Play()
		elseif current then
			current = nil
			camera.CameraType = Enum.CameraType.Custom
		end
	end

	player:GetAttributeChangedSignal("BoothIndex"):Connect(update)
	player.CharacterAdded:Connect(function()
		current = nil
		task.defer(update)
	end)
	update()
end

return CameraController
