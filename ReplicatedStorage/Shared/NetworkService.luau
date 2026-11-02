local NetworkService = {}

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local RunService = game:GetService("RunService")

-------------------------------------------------
-- VARIABLES
-------------------------------------------------
local Remotes: Folder = nil
local defaultGroup: Folder = nil

-------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------

--- get a group.
---
--- if group is nil, It'll return the __Default__ group.
local function GetGroup(group: string?): Folder
	if group == nil then
		return defaultGroup
	end

	local groupFolder = Remotes:FindFirstChild(group)
	return groupFolder
end

-------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------

--- Create a new remote event
---
--- SERVER ONLY
function NetworkService:Create(name: string, group: string?): RemoteEvent
	if RunService:IsClient() then
		error("NetworkServvice:Create() is only available from the server.")
	end

	local groupFolder = GetGroup(group)

	if groupFolder == nil then
		groupFolder = Instance.new("Folder")
		groupFolder.Parent = Remotes
		groupFolder.Name = group
	end

	if groupFolder:FindFirstChild(name) then
		return groupFolder:FindFirstChild(name)
	end

	local remote = Instance.new("RemoteEvent")
	remote.Parent = groupFolder
	remote.Name = name
	print("Created Remote : " .. name .. " / Group : " .. groupFolder.Name)
	return remote
end

--- Get a remote event
---
--- Doesn't create a new one.
function NetworkService:Get(name: string, group: string?): RemoteEvent?
	local groupFolder = GetGroup(group)
	if groupFolder == nil then
		error("Failed find the group, Name : " .. group)
	end
	return groupFolder:FindFirstChild(name)
end

--- NetworkService's initialize
function NetworkService:Init()
	if RunService:IsServer() then
		Remotes = Instance.new("Folder")
		Remotes.Parent = script
		Remotes.Name = "Remotes"

		defaultGroup = Instance.new("Folder")
		defaultGroup.Parent = Remotes
		defaultGroup.Name = "__Default__"
	elseif RunService:IsClient() then
		Remotes = script:WaitForChild("Remotes")
		defaultGroup = Remotes:WaitForChild("__Default__")
	end
end

return NetworkService
