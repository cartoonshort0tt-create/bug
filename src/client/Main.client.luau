--!strict
-- Client entry point.

local Controllers = script.Parent:WaitForChild("Controllers")

require(Controllers:WaitForChild("Hud")).start()
require(Controllers:WaitForChild("CameraController")).start()
require(Controllers:WaitForChild("InputWatch")).start()
require(Controllers:WaitForChild("Distractions")).start()
