local ReplicatedStorage = game:GetService("ReplicatedStorage")
task.wait(3)
local Services = script.Parent.Services
local Modules = {}

-- Load the modules
for _, v in ipairs(Services:GetDescendants()) do
	if not v:IsA("ModuleScript") then
		continue
	end
	pcall(function()
		Modules[v.Name] = require(v)
		--print("Loaded Module : ", v.Name)
	end)
end

for _, v in ipairs(ReplicatedStorage.Shared:GetDescendants()) do
	if not v:IsA("ModuleScript") or not v:HasTag("LoadOnServer") then
		continue
	end

	pcall(function()
		Modules[v.Name] = require(v)
		--print("Loaded Module : ", v.Name)
	end)
end

-- Init the modules
for name, module in pairs(Modules) do
	if module.Init ~= nil then
		pcall(function()
			module:Init()
			--print("Initialized Module : ", name)
		end)
	end
end

-- Start the modules
for name, module in pairs(Modules) do
	if module.Start ~= nil then
		pcall(function()
			module:Start()
			--print("Started Module : ", name)
		end)
	end
end
