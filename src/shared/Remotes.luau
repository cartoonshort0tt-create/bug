--!strict
-- RemoteEvents. The server creates them; clients wait for them. The server treats
-- every argument from a client as untrusted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Moved", -- client → server: the player touched an input while running or counting down
	"Restart", -- client → server: start again from 0
	"Continue", -- client → server: continue from the lost time (spends a credit or prompts a purchase)
	"Notify", -- server → client: (message: string)
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		folder = created
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.get(name: string): RemoteEvent
	assert(table.find(NAMES, name), "unknown remote " .. name)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
