--!strict
-- Targeting, the timing ring and swinging. The ring is drawn from the server's start
-- stamp using workspace:GetServerTimeNow(), and the hit time sent to the server is
-- the same synced clock, so the server can judge the swing exactly as the player saw it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer

local TIER_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(95, 109, 97),
	Rare = Color3.fromRGB(42, 111, 202),
	Epic = Color3.fromRGB(122, 69, 199),
	Legendary = Color3.fromRGB(185, 130, 10),
	Mythic = Color3.fromRGB(204, 58, 112),
}

type RingInfo = {
	id: number,
	uid: string,
	start: number,
	duration: number,
	green: { number },
	perfect: { number },
}

local SwingController = {}

function SwingController.start(hud: Hud.Hud)
	local RequestRing = Remotes.get("RequestRing")
	local Swing = Remotes.get("Swing")
	local bugsFolder = Workspace:WaitForChild("Bugs")

	local activeRing: RingInfo? = nil
	local target: BasePart? = nil
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = hud.gui

	local function now(): number
		return Workspace:GetServerTimeNow()
	end

	local function rootPosition(): Vector3?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root.Position else nil
	end

	-- Nearest catchable bug within the net's reach (on the ground plane).
	local function findTarget(): BasePart?
		local pos = rootPosition()
		if not pos then
			return nil
		end
		local reach = ((player:GetAttribute("NetReach") or 6) :: number) + 1
		local best: BasePart? = nil
		local bestDistance = reach
		for _, child in bugsFolder:GetChildren() do
			if child:IsA("BasePart") then
				local owner = child:GetAttribute("OwnerUserId")
				if owner == nil or owner == player.UserId then
					local d = (Vector3.new(child.Position.X, 0, child.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
					if d < bestDistance then
						best = child
						bestDistance = d
					end
				end
			end
		end
		return best
	end

	local function hideRing()
		activeRing = nil
		hud.ring.Visible = false
	end

	local function showRing(info: RingInfo)
		activeRing = info
		local green, perfect = info.green, info.perfect
		-- The shrinking circle has size (1 - p); the green band is p in [green1, green2].
		hud.ringGreen.Size = UDim2.fromScale(1 - green[1], 1 - green[1])
		hud.ringHole.Size = UDim2.fromScale(1 - green[2], 1 - green[2])
		local mid = (perfect[1] + perfect[2]) / 2
		hud.ringPerfect.Size = UDim2.fromScale(1 - mid, 1 - mid)
		hud.ringCircle.Size = UDim2.fromScale(1, 1)
		hud.ring.Visible = true
	end

	local function swing()
		local ring = activeRing
		if ring then
			hideRing()
			Swing:FireServer(ring.id, now())
			return
		end
		if target then
			local uid = target:GetAttribute("Uid")
			if type(uid) == "string" then
				RequestRing:FireServer(uid)
			end
		else
			hud:toast("Walk up to a bug, then swing!")
		end
	end

	Remotes.get("RingStarted").OnClientEvent:Connect(function(info: RingInfo)
		showRing(info)
	end)

	Remotes.get("CatchResult").OnClientEvent:Connect(function(result: { [string]: any })
		if not result.ok then
			hud:toast(result.reason, Color3.fromRGB(184, 64, 47))
			return
		end
		local parts = {}
		if result.perfect then
			table.insert(parts, "PERFECT!")
		end
		if result.variants then
			table.insert(parts, table.concat(result.variants, " "))
		end
		if result.mutation then
			table.insert(parts, result.mutation)
		end
		table.insert(parts, string.format("%s (%s) +%s", result.name, result.tier, result.valueText))
		hud:toast(table.concat(parts, " · "), TIER_COLORS[result.tier])
		if result.newSpecies then
			hud:toast("NEW Bugdex stamp! " .. (result.fact or ""), Color3.fromRGB(44, 122, 75))
		end
	end)

	Remotes.get("Notify").OnClientEvent:Connect(function(message: string)
		hud:toast(message)
	end)

	hud.swingButton.Activated:Connect(swing)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonR2 then
			swing()
		end
	end)

	RunService.RenderStepped:Connect(function()
		-- Animate the ring from the shared clock.
		local ring = activeRing
		if ring then
			local p = (now() - ring.start) / ring.duration
			if p > 1 + Catch.graceSeconds / ring.duration then
				-- Report the timeout so the server frees the ring now; it answers "Too late!".
				hideRing()
				Swing:FireServer(ring.id, now())
			else
				local size = math.clamp(1 - p, 0, 1)
				hud.ringCircle.Size = UDim2.fromScale(size, size)
			end
		end

		target = findTarget()
		highlight.Adornee = target
	end)

end

return SwingController
