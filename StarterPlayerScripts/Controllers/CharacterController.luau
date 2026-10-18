local CharacterController = {}

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Packages.Signal)

-------------------------------------------------
-- VARIABLES
-------------------------------------------------
local player = Players.LocalPlayer

local character: Model = nil
-------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------
CharacterController.onCharacterLoaded = Signal.new()
CharacterController.onStateChanged = Signal.new()

CharacterController.isIdle = false

-------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------
local function OnCharacterLoad(newCharacter: Model)
	character = newCharacter
	CharacterController.onCharacterLoaded:Fire(newCharacter)

	-- Link idle event
	local humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")

	RunService:BindToRenderStep("CheckCharacterIdle", Enum.RenderPriority.Character.Value, function()
		if humanoid.MoveDirection.Magnitude == 0 and not CharacterController.isIdle then
			CharacterController.isIdle = true
			CharacterController.onStateChanged:Fire(humanoid:GetState().Name, "Idle")
		elseif humanoid.MoveDirection.Magnitude ~= 0 and CharacterController.isIdle then
			CharacterController.onStateChanged:Fire("Idle", humanoid:GetState().Name)
			CharacterController.isIdle = false
		end
	end)

	humanoid.StateChanged:Connect(function(old, new)
		task.wait(0.05)
		if CharacterController.isIdle then
			CharacterController.onStateChanged:Fire(old, "Idle")
		else
			CharacterController.onStateChanged:Fire(old.Name, new.Name)
		end
	end)

	humanoid.Died:Once(function()
		RunService:UnbindFromRenderStep("CheckCharacterIdle")
	end)
end

-------------------------------------------------
-- PUBLIC API
-------------------------------------------------

--- CharacterController's initializing function
function CharacterController:Init()
	if player.Character ~= nil then
		OnCharacterLoad(player.Character)
	end

	player.CharacterAdded:Connect(function(newCharacter)
		OnCharacterLoad(newCharacter)
	end)
end

--- Start the CharacterController
function CharacterController:Start() end

--- Get the character
function CharacterController:GetCharacter(): Model
	if character == nil then
		self.onCharacterLoaded:Wait()
	end

	return character
end

--- Get the humanoid
function CharacterController:GetHumanoid(): Humanoid
	local char = CharacterController:GetCharacter()
	local humanoid = char:WaitForChild("Humanoid")

	return humanoid
end

--- Get the animator
function CharacterController:GetAnimator(): Animator
	local humanoid = CharacterController:GetHumanoid()
	local animator = humanoid:WaitForChild("Animator")

	return animator
end

--- Get the character's movement state
function CharacterController:GetState(): string
	if CharacterController.isIdle then
		return "Idle"
	else
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		return humanoid:GetState().Name
	end
end

return CharacterController
