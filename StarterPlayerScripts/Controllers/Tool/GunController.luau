-- Discord ID : TNewName(@po_qo) Roblox ID : TNewName(@Mopv_vqoM)
-- Since I'm not an English speaker, there are may a lot of grammer issues.

local GunController = {} -- Create the table. This is this module's main class. also, it follows "Singleton Pattern".

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local Players = game:GetService("Players") -- get "Players" service. Used to get player objects.
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- get "ReplicatedStorage" service. used to get shared codes, assets or more.
local RunService = game:GetService("RunService") -- get "RunService". used to character aiming every frame.
local TweenService = game:GetService("TweenService") -- get "TweenService". used to make animation about zooming.

local Trove = require(ReplicatedStorage.Packages.Trove) -- get "Trvoe". To manage memory leaks.
local GunUtil = require(ReplicatedStorage.Utils.GunUtil) -- get "GunUtil". To use gun global functions.

local InputController: typeof(require(script.Parent.Parent.InputController)) -- set type "InputController". It uses "InputAction" thing. Also, since these modules are not loaded, doesn't load right now.
local ToolController: typeof(require(script.Parent.ToolController)) -- set type "ToolController". to use tool functions, signals, or more.
local CharacterController: typeof(require(script.Parent.Parent.CharacterController)) -- set type "CharacterController". to manage character infos easily from StarterPlayerScripts.
local NetworkService: typeof(require(ReplicatedStorage.Shared.NetworkService)) -- set type "NetworkService". to communicate with client.

-------------------------------------------------
-- SETTINGS
-------------------------------------------------
local BODY_LINK_INTERVAL = 0.1 -- an interval that sends arms and head aiming to the server

local ZOOM_INFO = TweenInfo.new(0.23, Enum.EasingStyle.Sine, Enum.EasingDirection.Out) -- zooming tween has these info. To change easily, made as a variable.
local ZOOM_FOV = 35 -- Zoom fov. When the player zooms, the player's fov will smoothly set to it.
local DEAFULT_FOV = workspace.CurrentCamera.FieldOfView -- Default fov. When the player stops zooming, the player's zoom will smoothly set to it. Why variable? -> to save the starting FOV. because aftter zooming, you cannot find the normalFOV from the camera.
local ZOOM_SLOWNESS = 11 -- how much the player will be slowed.

-------------------------------------------------
-- VARIABLES
-------------------------------------------------
local player = Players.LocalPlayer -- get the local player
local mouse = player:GetMouse() -- get player's mouse

local UnequipTrove = Trove.new() -- There are two troves because they have a different life cycles.
local AnimTrove = Trove.new() -- this trove is about character rotating, arms rotating or something.

local Zooming = false -- set a variable that contains zooming info.
local ZoomTween: Tween = nil -- set a variable that contains current zoomTweening. used to manage fast zoom toggling.

local Shooting = false -- set a variable that contains "Is the player shooting?". used to shooting loop.
local CanShoot = true -- set a variable that contains "Can the player shoot?".
local Reloading = false -- set a variable that contains "Is the player reloading?".

-------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------

--------- ANIMATIONS --------------

--- Play the gun animations. (walking, Idle, jump and more)
local function PlayGunAnim(
	humanoid: Humanoid,
	animator: Animator,
	animSet: { [string]: Animation },
	trove: typeof(Trove.new()) -- a trove used to stop the gun anim.
) -- I wanted to use roblox's 'Animate' module to load Running or Idle animations but It doesn't load changed animations well. I used the animations as an 'action' instead.
	local animTracks: { [string]: AnimationTrack } = {}
	for name, anim in pairs(animSet) do -- for every animation..
		animTracks[name] = animator:LoadAnimation(anim) -- load and save it to the animTracks.
	end

	local lastAnimTrack: AnimationTrack? = nil -- save last playing-anim to stop it.
	local state = CharacterController:GetState() -- It returns the charater's state. (Running and FreeFalling. There's also, "IDLE" state) used to play the current state's animation

	local function PlayAnim(action: string) -- this code was called multiple times, so I made it as a function.
		if animTracks[action] == nil then -- if there's no anim,
			return -- return
		end

		if lastAnimTrack ~= nil and lastAnimTrack ~= animTracks[action] then -- If the anim is currently playing,
			lastAnimTrack:Stop() -- stop the animation.
		end

		lastAnimTrack = animTracks[action] -- save the animation that is currently playing.
		lastAnimTrack.Priority = Enum.AnimationPriority.Movement -- set animation's priority manually
		lastAnimTrack:Play() -- start animation (loop)
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

----------- AIMING -----------

--- Start Aiming
local function ZoomInCamera(humanoid: Humanoid)
	if Zooming then -- if already zooming,
		return -- skip
	end
	Zooming = true -- set the "Zooming" variable to true.
	if ZoomTween then -- If there's zoom tween,
		ZoomTween:Destroy() -- destroy it
	end

	ZoomTween = TweenService:Create(workspace.CurrentCamera, ZOOM_INFO, { FieldOfView = ZOOM_FOV }) -- create new zooming tween.
	ZoomTween:Play() -- start it. (start zooming)
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
local function DisableShooting() -- Though the code's length is really short, to make the code expandable, made it as a function.
	CanShoot = false
	Shooting = false
end

local function EnableShooting() -- Though the code's length is really short, to make the code expandable, made it as a function.
	CanShoot = true
end

local function Shoot(tool: Tool, shootTrack) -- shoot.
	shootTrack.Priority = Enum.AnimationPriority.Action -- Manually set the shoot animation's priority.
	shootTrack.Looped = false -- disable looped manually
	shootTrack:Play(0) -- play the anim. to remove transition, give 0 at the parameter

	local hitPos = mouse.Hit.Position -- get mouse position
	--GunUtil.ShowBullet(tool, hitPos) -- If the game is too laggy, It will be enabled. For better experience. currently, bullet shows from server.

	local onShootEvent = NetworkService:Get("OnShoot", "Gun") -- get shoot remote event
	onShootEvent:FireServer(tool, hitPos) -- To prevent hacking, sending a hit pos instead of the character.
	tool:SetAttribute("Ammo", tool:GetAttribute("Ammo") - 1) -- decrease the ammo. It will also be decreased from the server.
end

local function Reload(gun: Tool, reloadTrack: AnimationTrack) -- reload
	if Reloading then -- if reloading now,
		return -- skip
	end
	Reloading = true -- set reloading to true.
	DisableShooting() -- disable shooting
	reloadTrack.Priority = Enum.AnimationPriority.Action2 -- Manually set the shoot animation's priority.
	reloadTrack.Looped = false -- disable looping manually
	reloadTrack:Play(0) -- play the anim. To remove transition, give 0 at the parameter.

	reloadTrack.Ended:Once(
		function() -- to prevent memory leak, used :Once() instead of :Connect() / When reloading ended,
			local onReloadEvent = NetworkService:Get("OnReload", "Gun") -- get the remote
			local maxAmmo = GunUtil.GetInfo(gun).MaxAmmo -- get the gun's max ammo
			gun:SetAttribute("Ammo", maxAmmo) -- refill the ammo
			onReloadEvent:FireServer(gun) -- also fill the ammo from the server. For prevent hacking.
			EnableShooting() -- enable shooting
			Reloading = false -- stop reloading
		end
	)
end

--- Character Follows The Cursor.
local function moveBodyToCursor(character: Model, trove: typeof(Trove.new())) -- this function rotates the humanoidRootPart
	local hit = mouse.Hit -- get world mouse CFrame
	local hitPos = hit.Position -- get the mouse's hit position
	local humanoidRootPart: Part? = character:FindFirstChild("HumanoidRootPart") -- get character's humanoidRootPart
	if humanoidRootPart == nil then -- if failed to find the HumanoidRootPart,
		return -- return
	end
	-- Torso Moving
	local characterPos = humanoidRootPart.Position -- get character's position
	local flatTargetPos = Vector3.new(hitPos.X, characterPos.Y, hitPos.Z) -- removed y position.
	local LookAt = CFrame.lookAt(characterPos, flatTargetPos) -- get the final CFrame
	local humanoid = CharacterController:GetHumanoid() -- get the humanoid.

	if humanoid.Health > 0 and humanoid.SeatPart == nil then -- If can rotate the humanoidRootpart,
		humanoidRootPart:PivotTo(LookAt) -- Move the player
	end

	-- Head and arms Moving
	GunUtil.BodyLookThere(character, hitPos, trove) -- head and arms movement doesn't appear to other clients.
end

------------ GUN MAIN -------------

--- Enable Aiming on gun equip
local function LinkAiming(humanoid: Humanoid)
	local AimInput = InputController:GetAction("Gun", "Aim") -- get the aiming input.

	UnequipTrove:Add(AimInput.Pressed:Connect(function() -- when the InputAction is pressed,
		ZoomInCamera(humanoid) -- zoom in the camera
	end))
	UnequipTrove:Add(AimInput.Released:Connect(function() -- when the InputAction is released,
		ZoomOutCamera(humanoid) -- zoom out the camera
	end))
end

--- Enable Shooting on gun equip
local function LinkShooting(tool: Tool, gunInfo: typeof(GunUtil.GetInfo()), animator: Animator)
	Shooting = false -- set state to false
	local ShootInput = InputController:GetAction("Gun", "Shoot") -- get the shooting input
	UnequipTrove:Add(ShootInput.Pressed:Connect(function() -- on Shoot Input pressed
		if CanShoot then -- if the player can shoot
			Shooting = true -- start shooting
		end
	end))
	UnequipTrove:Add(ShootInput.Released:Connect(function() -- on shoot input released
		Shooting = false -- stop shooting
	end))

	-- if there's no "ammo" attribute, reset it
	if tool:GetAttribute("Ammo") == nil then -- if failed to find the ammo,
		tool:SetAttribute("Ammo", gunInfo.MaxAmmo) -- set to max value. (Server also has this code)
	end

	-- shoot loop
	UnequipTrove:Add(task.spawn(function() -- add a loop that will be destroyed on weapon unequip.
		local shootAnim = GunUtil.GetAnimationSet(tool).Shoot -- get a shooting animation. It is also used in server so its code is shared.
		local shootTrack = animator:LoadAnimation(shootAnim) -- load the anim

		while true do -- shooting loop. To support holding mechanic, used 'while'.
			task.wait() -- wait for a bit. To prevent error.
			if Shooting and CanShoot and tool:GetAttribute("Ammo") > 0 then -- If the player can shoot
				Shoot(tool, shootTrack) -- shoot
				task.wait(gunInfo.FireRate) -- wait the fire rate.
			end
		end
	end))
end

--- Enable Reloading on gun equip
local function LinkReload(tool: Tool, animator: Animator)
	local ReloadInput = InputController:GetAction("Gun", "Reload") -- get the reloading input
	local reloadAnim = GunUtil.GetAnimationSet(tool).Reload -- get the reloading animation
	local reloadTrack = animator:LoadAnimation(reloadAnim) -- load it

	UnequipTrove:Add(ReloadInput.Released:Connect(function() -- on released,
		Reload(tool, reloadTrack) -- reload.
	end))
end

-- Enable body aiming on gun equip
local function LinkBodyAiming(tool: Tool)
	-- Set up
	local AttachEvent = NetworkService:Get("Attach", "Gun") -- get the remote. this remote attachs the weapon.

	AnimTrove:Clean() -- Before start to resume animating, cleanup animTrove
	AttachEvent:FireServer(tool) -- attach the gun to the arm.

	-- Character Rotating
	local character = CharacterController:GetCharacter() -- get the player's character
	RunService:BindToRenderStep("CharacterRotation", Enum.RenderPriority.Character.Value, function() -- every frame,
		moveBodyToCursor(character, AnimTrove) -- rotate the character.
	end)

	-- Link Body Aiming
	local BodyLinkEvent = NetworkService:Get("BodyLink", "Gun") -- get the remote, "BodyLink" from "Guns"
	local ResetBodyAim = NetworkService:Get("ResetBodyAim", "Gun") -- get the remote, "ResetBodyAim" from "Gun"

	AnimTrove:Add(task.spawn(function() -- add the loop
		while true do -- infinite loop
			task.wait(BODY_LINK_INTERVAL) -- every BODY_LINK_INTERVAL time,
			BodyLinkEvent:FireServer(mouse.Hit.Position) -- send the mouse position to the server. This will make the arms and head's movement sync with the client.
		end
	end))

	AnimTrove:Add(function() -- on animation stopping,
		ResetBodyAim:FireServer() -- reset the player's body and head's animation.
	end)
end

--- On Gun Equip
local function OnGunEquip(tool: Tool)
	if not tool:HasTag("gun") then -- if the tool is not a gun
		return -- return
	end

	AnimTrove:Clean() -- stop play current gun's animations.

	InputController:EnableContext("Gun") -- Enable the gun's inputs.
	local humanoid = CharacterController:GetHumanoid() -- get player's humanoid
	local animator = CharacterController:GetAnimator() -- get player's animator
	local gunInfo = GunUtil.GetInfo(tool) -- get the gun's info. Like damage, fireRate and more.

	-- Aimings
	LinkAiming(humanoid)

	-- Shooting
	LinkShooting(tool, gunInfo, animator)

	-- reloading
	LinkReload(tool, animator)

	-- body aiming
	LinkBodyAiming(tool)

	-- Clean trove on die
	local humanoid = CharacterController:GetHumanoid() -- get player's humanoid
	AnimTrove:Add(humanoid.Died:Connect(function() -- On the player died,
		AnimTrove:Clean() -- clean the anim trove.
	end))

	-- Animations
	local anims = GunUtil.GetAnimationSet(tool) -- get gun animations
	local animator = humanoid:FindFirstChildOfClass("Animator") -- get the player's animator
	PlayGunAnim(humanoid, animator, anims, AnimTrove) -- play the gun movement animations.
end

--- On Gun Unequip
local function OnGunUnequip(tool: Tool)
	if not tool:HasTag("gun") then -- if the tool is not a gun
		return -- return
	end

	UnequipTrove:Clean() -- clena the trove
	AnimTrove:Clean() -- clean the trove

	InputController:DisableContext("Gun") -- disable gun inputs
	local UnattachEvent = NetworkService:Get("Unattach", "Weapon") -- get the remote, "Unattach" from the "Weapon" folder

	UnattachEvent:FireServer() -- unattach the gun from the player
	RunService:UnbindFromRenderStep("CharacterRotation") -- stop rotating the player
	ZoomOutCamera(CharacterController:GetHumanoid()) -- stop zooming.
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
		if tool:HasTag("gun") then -- if the tool is the gun
			OnGunEquip(tool) -- call the function.
		end
	end)

	-- On Gun Unequip
	ToolController.OnUnEquip:Connect(function(tool) -- when the tool unequipped
		if tool:HasTag("gun") then -- if the tool is the gun
			OnGunUnequip(tool) -- call the function
		end
	end)

	-- On Kill
	local OnKillEvent = NetworkService:Get("OnKill", "Gun") -- get "OnKill" Remote event from the "Gun" folder.
	OnKillEvent.OnClientEvent:Connect(function() -- when OnKill event received from the server...
		ReplicatedStorage.Sounds.Combat.GunKill:Play() -- play the kill sound
	end)
end

return GunController
