--!strict
-- Server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create the remotes first so clients never wait on a missing one.
require(ReplicatedStorage.Shared.Remotes)

local Services = script.Parent.Services
local LobbyBuilder = require(Services.LobbyBuilder)
local Store = require(Services.Store)
local Leaderboards = require(Services.Leaderboards)
local NothingService = require(Services.NothingService)
local Purchases = require(Services.Purchases)

Store.start()
local lobby = LobbyBuilder.build()
Leaderboards.start(lobby)
NothingService.start(lobby)
Purchases.start()
