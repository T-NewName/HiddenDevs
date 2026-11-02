local GunService = {}

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkService: typeof(require(ReplicatedStorage.Shared.NetworkService))
local GunUtil = require(ReplicatedStorage.Utils.GunUtil)
local RayUtil = require(ReplicatedStorage.Utils.RayUtil)

-------------------------------------------------
-- VARIABLES
-------------------------------------------------

-------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------

--- Attach weapon to player's right arm
local function AttachWeapon(character: Model, weapon: Tool)
	local RightArm: Part = character:FindFirstChild("Right Arm")
	local Humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
	local Handle: Part = weapon:FindFirstChild("Handle")

	if RightArm == nil or Humanoid == nil or Humanoid.Health <= 0 or Handle == nil then
		return
	end

	local Motor6D = Instance.new("Motor6D")
	Motor6D.Parent = RightArm
	Motor6D.Name = "Handle"
	Motor6D.Part0 = RightArm
	Motor6D.Part1 = Handle

	RightArm:FindFirstChild("RightGrip"):Destroy()
end

--- Unattach weapon from player's right arm
local function UnattachWeapon(character: Model)
	local RightArm: Part = character:FindFirstChild("Right Arm")
	local Humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")

	if RightArm == nil or Humanoid == nil or Humanoid.Health <= 0 then
		return
	end

	local attach = RightArm:FindFirstChild("Handle")
	if attach ~= nil and attach:IsA("Motor6D") then
		attach:Destroy()
		print("CLEANED")
	end
end

-------------------------------------------------
-- PUBLIC API
-------------------------------------------------

--- GunService's initializing function
function GunService:Init()
	NetworkService = require(ReplicatedStorage.Shared.NetworkService)
end

--- Start the GunService
function GunService:Start()
	local OnShootEvent = NetworkService:Create("OnShoot", "Gun")
	local OnReloadEvent = NetworkService:Create("OnReload", "Gun")
	local OnKillEvent = NetworkService:Create("OnKill", "Gun")

	-- On shoot
	OnShootEvent.OnServerEvent:Connect(function(player, gun: Tool, hitPos: Vector3)
		if gun:GetAttribute("Ammo") == nil or gun:GetAttribute("Ammo") == 0 then
			warn("This gun has no ammo")
			return
		end
		gun:SetAttribute("Ammo", gun:GetAttribute("Ammo") - 1)
		--GunUtil.ShowBullet(gun, hitPos)
		-- Ray Cast
		local muzzle = GunUtil.GetMuzzle(gun)
		if muzzle == nil then
			return
		end
		local direction = (hitPos - muzzle.WorldPosition) * 10

		local raycastResult = workspace:Raycast(muzzle.WorldPosition, direction)
		if raycastResult ~= nil then
			local hit = raycastResult.Instance
			--RayUtil.Visualize(muzzle.WorldPosition, direction, raycastResult.Position)
			GunUtil.ShowBullet(gun, raycastResult.Position)
			local humanoid: Humanoid = hit.Parent:FindFirstChild("Humanoid")
			if humanoid ~= nil and humanoid.Health > 0 and player.Character ~= hit.Parent then
				local gunInfo = GunUtil.GetInfo(gun)
				humanoid.Health -= gunInfo.Damage
				if humanoid.Health <= 0 then
					OnKillEvent:FireClient(player)
				end
			end
		else
			GunUtil.ShowBullet(gun, hitPos)
		end
	end)

	-- Reload
	OnReloadEvent.OnServerEvent:Connect(function(player, gun: Tool)
		local gunInfo = GunUtil.GetInfo(gun)
		gun:SetAttribute("Ammo", gunInfo.MaxAmmo)
	end)

	-- weapon references
	local AttachEvent = NetworkService:Create("Attach", "Gun")
	local UnattachEvent = NetworkService:Create("Unattach", "Gun")
	local BodyLinkEvent = NetworkService:Create("BodyLink", "Gun")
	local ResetBodyAim = NetworkService:Create("ResetBodyAim", "Gun")

	-- Attach
	AttachEvent.OnServerEvent:Connect(function(player, weapon: Tool)
		if not weapon:IsA("Tool") or not weapon:HasTag("weapon") then
			return
		end

		local character = player.Character or player.CharacterAdded:Wait()
		AttachWeapon(character, weapon)
	end)

	-- Unattach
	UnattachEvent.OnServerEvent:Connect(function(player)
		local character = player.Character or player.CharacterAdded:Wait()
		UnattachWeapon(character)
	end)

	-- Link player's body and arms
	BodyLinkEvent.OnServerEvent:Connect(function(player, hitPos: Vector3)
		local character = player.Character or player.CharacterAdded:Wait()
		GunUtil.BodyLookThere(character, hitPos)
	end)

	-- Reset player's body and arms
	ResetBodyAim.OnServerEvent:Connect(function(player)
		local character = player.Character or player.CharacterAdded:Wait()
		GunUtil.ResetBody(character)
	end)
end

-------------------------------------------------
-- MAIN
-------------------------------------------------
return GunService
