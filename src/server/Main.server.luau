--!strict
-- Server entry point: builds the world and starts every service in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Creating the remotes first means clients never wait on a missing one.
require(ReplicatedStorage.Shared.Remotes)

local Services = script.Parent.Services
local WorldService = require(Services.WorldService)
local DataService = require(Services.DataService)
local SpawnService = require(Services.SpawnService)
local CatchService = require(Services.CatchService)
local EconomyService = require(Services.EconomyService)

local world = WorldService.build()
DataService.start()
SpawnService.start(world.bugs)
CatchService.start()
EconomyService.start(world)

if RunService:IsStudio() then
	local EconomyCheck = require(ReplicatedStorage.Shared.EconomyCheck)
	local report = EconomyCheck.report()
	local _, ok = EconomyCheck.run()
	if ok then
		print(report)
	else
		warn(report)
	end
end
