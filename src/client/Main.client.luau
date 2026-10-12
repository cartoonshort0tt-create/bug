--!strict
-- Client entry point.

local Controllers = script.Parent:WaitForChild("Controllers")
local Hud = require(Controllers:WaitForChild("Hud"))
local SwingController = require(Controllers:WaitForChild("SwingController"))
local BugVisuals = require(Controllers:WaitForChild("BugVisuals"))

local hud = Hud.new()
SwingController.start(hud)
BugVisuals.start()
