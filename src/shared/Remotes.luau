--!strict
-- All RemoteEvents in one place. The server creates them; clients wait for them.
-- Every handler on the server must treat arguments as untrusted (see CatchService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"RequestRing", -- client → server: (bugUid: string)
	"RingStarted", -- server → client: (ring: RingInfo)
	"Swing", -- client → server: (ringId: number, hitTime: number)
	"CatchResult", -- server → client: (result: table)
	"Notify", -- server → client: (message: string)
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
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
