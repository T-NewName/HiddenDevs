local InputController = {}

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-------------------------------------------------
-- VARIABLES
-------------------------------------------------

-------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------

--- Get The Context
local function GetContext(contextName: string): InputContext?
	local a = script:FindFirstChild(contextName)
	if a:IsA("InputContext") then
		return a
	else
		return nil
	end
end

-------------------------------------------------
-- PUBLIC API
-------------------------------------------------

--- InputController's initializing function
function InputController:Init() end

--- Start the InputController
function InputController:Start() end

--- Get the action
function InputController:GetAction(contextName: string, actionName: string): InputAction
	local context = GetContext(contextName)
	if context == nil then
		error("Failed to find a context")
	end

	local a = context:FindFirstChild(actionName)
	if  a ~= nil and a:IsA("InputAction") then
		return a
	else
		error("Failed to find an action.")
	end
end

--- Enable all actions in this context
function InputController:EnableContext(contextName: string)
	local context = GetContext(contextName)
	if context ~= nil then
		context.Enabled = true
	end
end

--- Disable all actions in this context
function InputController:DisableContext(contextName: string)
	local context = GetContext(contextName)
	if context ~= nil then
		context.Enabled = false
	end
end

-------------------------------------------------
-- MAIN
-------------------------------------------------
return InputController
