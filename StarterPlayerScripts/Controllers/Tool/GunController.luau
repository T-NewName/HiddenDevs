-- Discord ID : TNewName(@po_qo) Roblox ID : TNewName(@Mopv_vqoM)

local GunController = {}
-------------------------------------------------
-- SERVICES
-------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ToolController = require(script.Parent.ToolController)
local Trove = require(ReplicatedStorage.Packages.Trove)
local GunUtil = require(ReplicatedStorage.Utils.GunUtil)

local InputController: typeof(require(script.Parent.Parent.InputController))
local WeaponController: typeof(require(script.Parent.WeaponController))
local CharacterController: typeof(require(script.Parent.Parent.CharacterController))
local NetworkService: typeof(require(ReplicatedStorage.Shared.NetworkService))

-------------------------------------------------
-- SETTINGS
-------------------------------------------------
local BODY_LINK_INTERVAL = 0.1 -- an interval that sends arms and head aiming to the server

local ZOOM_INFO = TweenInfo.new(0.23, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local ZOOM_FOV = 35
local DEAFULT_FOV = workspace.CurrentCamera.FieldOfView
local ZOOM_SLOWNESS = 11

-------------------------------------------------
-- VARIABLES
-------------------------------------------------
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local UnequipTrove = Trove.new() -- There are two troves because they have a different life cycles.
local AnimTrove = Trove.new() -- this trove is about character rotating, arms rotating or something.

local Zooming = false
local ZoomTween: Tween = nil

local Shooting = false
local CanShoot = true
local Reloading = false

-------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------

--------- ANIMATIONS --------------

--- Play the gun animations. (walking, Idle, jump and more)
local function PlayGunAnim(
	humanoid: Humanoid,
	animator: Animator,
	animSet: { [string]: Animation },
	trove: typeof(Trove.new())
) -- I wanted to use roblox's 'Animate' module to load Running or Idle animations but It doesn't load changed animations well. I used the animations as an 'action' instead.
	local animTracks: { [string]: AnimationTrack } = {}
	for name, anim in pairs(animSet) do -- load all animations and save it to the animTracks.
		animTracks[name] = animator:LoadAnimation(anim)
	end

	local lastAnimTrack: AnimationTrack? = nil
	local state = CharacterController:GetState() -- It returns the charater's state. (Running and FreeFalling. There's also, "IDLE" state) used to play the current state's animation

	local function PlayAnim(action: string) -- It is called multiple times, so I made it as a function.
		if animTracks[action] == nil then
			return
		end

		if lastAnimTrack ~= nil then -- If the anim is currently playing,
			if lastAnimTrack == animTracks[action] then
				return
			end
			lastAnimTrack:Stop() -- stop the animation.
		end

		lastAnimTrack = animTracks[action] -- save the animation that is currently playing.
		if lastAnimTrack == nil then
			return
		end
		lastAnimTrack.Priority = Enum.AnimationPriority.Movement
		animTracks[action]:Play()
	end

	PlayAnim(state) -- play the current state's animation

	trove:Add(function() -- if the animTrove cleaned up,
		-- On Cleanup
		if lastAnimTrack ~= nil then
			lastAnimTrack:Stop() -- stop the current animation.
		end
	end)

	trove:Add(CharacterController.onStateChanged:Connect( -- When the player's state changed, (Including IDLE)
		function(old, new)
			PlayAnim(new) -- play the new animation.
		end
	))
end

--------- OTHERS -----------

--- Character Follows The Cursor.
local function moveBodyToCursor(character: Model, trove: typeof(Trove.new())) -- this function rotates the humanoidRootPart
	local hit = mouse.Hit
	local hitPos = hit.Position -- get the mouse's hit position
	local humanoidRootPart: Part? = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart == nil then
		return
	end
	-- Torso Moving
	local characterPos = humanoidRootPart.Position
	local flatTargetPos = Vector3.new(hitPos.X, characterPos.Y, hitPos.Z) -- removed y
	local LookAt = CFrame.lookAt(characterPos, flatTargetPos) -- the final CFrame
	local humanoid = CharacterController:GetHumanoid() -- get the humanoid.

	if humanoid.Health > 0 and humanoid.SeatPart == nil then -- If can rotate the humanoidRootpart,
		humanoidRootPart:PivotTo(LookAt) -- Move the player
	end

	-- Head and arms Moving
	GunUtil.BodyLookThere(character, hitPos, trove) -- head and arms movement doesn't appear to other clients.
end

----------- AIMING -----------

--- Start Aiming
local function ZoomInCamera(humanoid: Humanoid)
	if Zooming then
		return
	end
	Zooming = true
	if ZoomTween then -- If already zooming,
		ZoomTween:Destroy() -- stop zooming
	end

	ZoomTween = TweenService:Create(workspace.CurrentCamera, ZOOM_INFO, { FieldOfView = ZOOM_FOV }) -- create new zooming tween.
	ZoomTween:Play()
	humanoid.WalkSpeed -= ZOOM_SLOWNESS -- slow the player
end

--- End Aiming
local function ZoomOutCamera(humanoid: Humanoid)
	if not Zooming then
		return
	end
	Zooming = false
	if ZoomTween then -- If already zooming
		ZoomTween:Destroy() -- stop zooming
	end

	ZoomTween = TweenService:Create(workspace.CurrentCamera, ZOOM_INFO, { FieldOfView = DEAFULT_FOV }) -- create new zooming tween.
	ZoomTween:Play()
	humanoid.WalkSpeed += ZOOM_SLOWNESS -- revert the player's speed
end

------- Others --------
local function DisableShooting() -- To make expandable.
	CanShoot = false
	Shooting = false
end

local function EnableShooting()
	CanShoot = true
end

local function Shoot(tool: Tool, shootTrack)
	shootTrack.Priority = Enum.AnimationPriority.Action -- Manually set the shoot animation's priority.
	shootTrack.Looped = false
	shootTrack:Play(0)

	local hitPos = mouse.Hit.Position
	--GunUtil.ShowBullet(tool, hitPos) -- If the game is too laggy, It will be enabled. For better experience. currently, bullet shows from server.

	local onShootEvent = NetworkService:Get("OnShoot", "Gun") -- get shoot remote event
	onShootEvent:FireServer(tool, hitPos) -- shoot.
	tool:SetAttribute("Ammo", tool:GetAttribute("Ammo") - 1) -- reduce the ammo. It will be also decreased from the server.
end

local function Reload(gun: Tool, reloadTrack: AnimationTrack)
	if Reloading then
		return
	end
	Reloading = true
	DisableShooting()
	reloadTrack.Priority = Enum.AnimationPriority.Action2 -- Manually set the shoot animation's priority.
	reloadTrack.Looped = false
	reloadTrack:Play(0)

	reloadTrack.Ended:Once(function() -- to prevent memory leak, used :Once() instead of :Connect()
		local onReloadEvent = NetworkService:Get("OnReload", "Gun") -- get the remote
		onReloadEvent:FireServer(gun) -- also fill the ammo from the server.
		EnableShooting()
		Reloading = false
	end)
end

-------------------------------------------------
-- PUBLIC API
-------------------------------------------------

--- GunController's initializing function
function GunController:Init()
	ToolController = require(script.Parent.ToolController)
	InputController = require(script.Parent.Parent.InputController)
	CharacterController = require(script.Parent.Parent.CharacterController)
	NetworkService = require(ReplicatedStorage.Shared.NetworkService)
end

--- Start the GunController
function GunController:Start()
	-- On Gun Equip
	ToolController.OnEquip:Connect(function(tool) -- when the tool equipped
		if not tool:HasTag("gun") then -- if it's not a gun
			return -- return
		end

		AnimTrove:Clean() -- stop play current gun's animations.

		InputController:EnableContext("Gun") -- Enable the gun's inputs.
		local humanoid = CharacterController:GetHumanoid()
		local animator = CharacterController:GetAnimator()
		local gunInfo = GunUtil.GetInfo(tool) -- get the gun's info. Like damage, fireRate and more.
		-- Aimings
		local AimInput = InputController:GetAction("Gun", "Aim") -- get the aiming input.

		UnequipTrove:Add(AimInput.Pressed:Connect(function() -- Zoom In
			ZoomInCamera(humanoid)
		end))
		UnequipTrove:Add(AimInput.Released:Connect(function() -- Zoom Out
			ZoomOutCamera(humanoid)
		end))

		-- Shooting
		Shooting = false
		local ShootInput = InputController:GetAction("Gun", "Shoot") -- get the shooting input

		UnequipTrove:Add(ShootInput.Pressed:Connect(function() -- on Shoot Input pressed
			if CanShoot then
				Shooting = true -- start shooting
			end
		end))
		UnequipTrove:Add(ShootInput.Released:Connect(function() -- on shoot input released
			Shooting = false -- stop shooting
		end))

		-- if there's no "ammo" attribute, reset it
		if tool:GetAttribute("Ammo") == nil then
			tool:SetAttribute("Ammo", gunInfo.MaxAmmo)
		end

		-- shoot loop
		UnequipTrove:Add(task.spawn(function() -- add a loop that will be destroyed on weapon unequip.
			local shootAnim = GunUtil.GetAnimationSet(tool).Shoot -- get a shooting animation. It is also used in server so its code is shared.
			local shootTrack = animator:LoadAnimation(shootAnim)

			while true do -- shooting loop
				task.wait()
				if Shooting and CanShoot and tool:GetAttribute("Ammo") > 0 then -- If the player can shoot
					Shoot(tool, shootTrack) -- shoot
					task.wait(gunInfo.FireRate) -- wait the fire rate.
				end
			end
		end))

		-- reloading
		local ReloadInput = InputController:GetAction("Gun", "Reload") -- get the reloading input
		local reloadAnim = GunUtil.GetAnimationSet(tool).Reload -- get the reloading animation
		local reloadTrack = animator:LoadAnimation(reloadAnim) -- load it

		UnequipTrove:Add(ReloadInput.Released:Connect(function() -- on released,
			Reload(tool, reloadTrack) -- reload.
		end))

		-- Set up
		local AttachEvent = NetworkService:Get("Attach", "Gun") -- get the remote. this remote attachs the weapon.

		AnimTrove:Clean()
		AttachEvent:FireServer(tool) -- attach the gun to the arm.

		-- Character Rotating
		local character = CharacterController:GetCharacter()
		RunService:BindToRenderStep("CharacterRotation", Enum.RenderPriority.Character.Value, function() -- every frame,
			moveBodyToCursor(character, AnimTrove) -- rotate the character.
		end)

		-- Link Body Aiming
		local BodyLinkEvent = NetworkService:Get("BodyLink", "Gun")
		local ResetBodyAim = NetworkService:Get("ResetBodyAim", "Gun")

		AnimTrove:Add(task.spawn(function() -- add the loop
			while true do -- infinite loop
				task.wait(BODY_LINK_INTERVAL) -- every BODY_LINK_INTERVAL time,
				BodyLinkEvent:FireServer(mouse.Hit.Position) -- send the mouse position to the server. This will make the arms and head's movement sync with the client.
			end
		end))

		AnimTrove:Add(function() -- on animation stopping,
			ResetBodyAim:FireServer() -- reset the player's body and head's animation.
		end)

		-- Clean trove on die
		local humanoid = CharacterController:GetHumanoid()
		AnimTrove:Add(humanoid.Died:Connect(function() -- On the player died,
			AnimTrove:Clean() -- clean the anim trove.
		end))

		-- Animations
		local anims = GunUtil.GetAnimationSet(tool)
		local animator = humanoid:FindFirstChildOfClass("Animator")
		PlayGunAnim(humanoid, animator, anims, AnimTrove) -- play the gun movement animations.
	end)

	-- On Gun Unequip
	ToolController.OnUnEquip:Connect(function(tool)
		if not tool:HasTag("gun") then
			return
		end

		UnequipTrove:Clean() -- clena the trove
		AnimTrove:Clean() -- clean the trove

		InputController:DisableContext("Gun") -- disable gun inputs
		local UnattachEvent = NetworkService:Get("Unattach", "Weapon")

		UnattachEvent:FireServer() -- unattach the gun from the player
		RunService:UnbindFromRenderStep("CharacterRotation") -- stop rotating the player
		ZoomOutCamera(CharacterController:GetHumanoid()) -- stop zooming.
	end)

	-- On Kill
	local OnKillEvent = NetworkService:Get("OnKill", "Gun")
	OnKillEvent.OnClientEvent:Connect(function()
		ReplicatedStorage.Sounds.Combat.GunKill:Play() -- play the kill sound
	end)
end

return GunController
