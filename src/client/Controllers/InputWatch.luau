--!strict
-- Once the player is seated and the countdown has started, ANY input ends the run:
-- mouse movement, clicks or scrolling, any key, touching the screen, gamepad buttons
-- or sticks. (Standing up is detected on the server.) This deliberately ignores
-- whether the input hit a GUI: clicking a distraction counts too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local InputWatch = {}

local IGNORED: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Accelerometer] = true, -- phones report these without anyone touching
	[Enum.UserInputType.Gyro] = true,
	[Enum.UserInputType.Focus] = true,
	[Enum.UserInputType.None] = true,
	[Enum.UserInputType.TextInput] = true,
}

function InputWatch.start()
	local Moved = Remotes.get("Moved")
	local lastSent = 0

	local function watching(): boolean
		local phase = player:GetAttribute("RunPhase")
		return phase == "running" or phase == "countdown"
	end

	local function report()
		if not watching() then
			return
		end
		-- One report per half second is plenty; the server ends the run on the first.
		local t = os.clock()
		if t - lastSent < 0.5 then
			return
		end
		lastSent = t
		Moved:FireServer()
	end

	local function isGamepad(t: Enum.UserInputType): boolean
		return t.Name:sub(1, 7) == "Gamepad"
	end

	UserInputService.InputBegan:Connect(function(input)
		if not IGNORED[input.UserInputType] then
			report()
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		local t = input.UserInputType
		if IGNORED[t] then
			return
		end
		if isGamepad(t) then
			-- Sticks drift a little on their own; triggers and sticks past the deadzone count.
			if input.Position.Magnitude > Config.gamepadDeadzone then
				report()
			end
		elseif t == Enum.UserInputType.MouseMovement then
			if input.Delta.Magnitude > 0 then
				report()
			end
		else
			report() -- mouse wheel, touch moves, anything else
		end
	end)

	-- The phone thumbstick and jump button are touches, so they're already covered.
	-- Reset the debounce whenever the phase changes so the next phase reports at once.
	player:GetAttributeChangedSignal("RunPhase"):Connect(function()
		lastSent = 0
	end)
end

return InputWatch
