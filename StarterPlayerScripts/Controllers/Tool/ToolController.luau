local ToolController = {}

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local CharacterController: typeof(require(StarterPlayer.StarterPlayerScripts.Controllers.CharacterController)) = nil
local Signal = require(ReplicatedStorage.Packages.Signal)

-------------------------------------------------
-- VARIABLES
-------------------------------------------------
local player = Players.LocalPlayer
local character: Model = nil

-------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------
ToolController.OnEquip = Signal.new()
ToolController.OnUnEquip = Signal.new()

-------------------------------------------------
-- PUBLIC API
-------------------------------------------------

--- ToolController's initializing function
function ToolController:Init()
	CharacterController = require(script.Parent.Parent.CharacterController)
end

--- Start the ToolController
function ToolController:Start()
	-- charater init
	character = CharacterController:GetCharacter()

	-- connecting
	local function OnChildAdded(tool: Instance)
		if not tool:IsA("Tool") then
			return
		end
		ToolController.OnEquip:Fire(tool)

		tool:GetPropertyChangedSignal("Parent"):Once(function()
			ToolController.OnUnEquip:Fire(tool)
		end)
	end

	local connection = character.ChildAdded:Connect(function(tool)
		OnChildAdded(tool)
	end)

	-- Readd a character
	CharacterController.onCharacterLoaded:Connect(function(char)
		character = char
		connection:Disconnect()
		connection = character.ChildAdded:Connect(function(tool)
			OnChildAdded(tool)
		end)
	end)
end

return ToolController
