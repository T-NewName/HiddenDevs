-- Discord ID : TNewName(@po_qo) Roblox ID : TNewName(@Mopv_vqoM)
-- Since I'm not an English speaker, there are may a lot of grammer issues.
-- Used Community Modules : Signal,Trove (by sleitnick)

local GunController = {} -- Create the table. This is this module's main class. also, it follows "Singleton Pattern".

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local Players = game:GetService("Players") -- Used to get player objects.
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- used to get shared codes, assets or more.
local RunService = game:GetService("RunService") -- used to character aiming every frame.
local TweenService = game:GetService("TweenService") -- used to make animation about zooming.

local Trove = require(ReplicatedStorage.Packages.Trove) -- To manage memory leaks and lifecycles.
local GunUtil = require(ReplicatedStorage.Utils.GunUtil) -- To use global gun functions.

-- My custom modules
local InputController: typeof(require(script.Parent.Parent.InputController)) -- It uses "InputAction" thing. Also, since these modules are not loaded, doesn't load right now. (only type)
local ToolController: typeof(require(script.Parent.ToolController)) -- to use tool functions, signals, or more.
local CharacterController: typeof(require(script.Parent.Parent.CharacterController)) -- to manage character infos easily from StarterPlayerScripts.
local NetworkService: typeof(require(ReplicatedStorage.Shared.NetworkService)) -- to communicate with client. (Remote Event thingy)

-------------------------------------------------
-- SETTINGS
-------------------------------------------------
local BODY_LINK_INTERVAL = 0.1 -- an interval that sends arms and head pos to the server

local ZOOM_INFO = TweenInfo.new(0.23, Enum.EasingStyle.Sine, Enum.EasingDirection.Out) -- zooming tween has these info. To change easily, made as a variable.
local ZOOM_FOV = 35 -- Zoom fov. When the player zooms, the player's fov will smoothly set to it.
local DEAFULT_FOV = workspace.CurrentCamera.FieldOfView -- Default fov. When the player stops zooming, the player's zoom will smoothly set to it. Why variable? -> to save the starting FOV. because aftter zooming, you cannot find the normalFOV from the camera.
local ZOOM_SLOWNESS = 11 -- how much the player will be slowed.

-------------------------------------------------
-- VARIABLES
-------------------------------------------------
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local UnequipTrove = Trove.new() -- it cares about weapon cycle
local AnimTrove = Trove.new() -- it cares about character rotating, arms rotating or something.

local Zooming = false
local ZoomTween: Tween = nil -- used to manage fast zoom toggling. (When the user toggles during tweening then, cancel it)

local Shooting = false -- used to shooting loop.
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
	trove: typeof(Trove.new()) -- a trove used to stop the gun anim.
) -- I wanted to use roblox's 'Animate' module to load Running or Idle animations but It doesn't load changed animations well. I used the animations as an 'action' instead.
	local animTracks: { [string]: AnimationTrack } = {}
	for name, anim in pairs(animSet) do -- for every animation..
		animTracks[name] = animator:LoadAnimation(anim) -- load it
	end

	local lastAnimTrack: AnimationTrack? = nil -- save last playing-anim to stop it.
	local state = CharacterController:GetState() -- It returns the charater's state. (Running and FreeFalling. There's also, "IDLE" state) used to play the current state's animation

	local function PlayAnim(action: string) -- multiple calling -> I made it as a function.
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

	trove:Add(function() -- when animation cycle ended,
		if lastAnimTrack ~= nil then
			lastAnimTrack:Stop() -- stop the current animation.
		end
	end)

	trove:Add(CharacterController.onStateChanged:Connect( -- When the player's state changed, (Including IDLE)
		function(old, new)
			PlayAnim(new) -- play the current state's animation.
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
	humanoid.WalkSpeed += ZOOM_SLOWNESS
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
	shootTrack.Looped = false
	shootTrack:Play(0) -- play the anim. To remove transition, give 0 at the parameter (removing fade time)

	local hitPos = mouse.Hit.Position
	--GunUtil.ShowBullet(tool, hitPos) -- Bullets appear on the server now, but this code makes them appear on the client! (Disabled it because I didn't want to use too many remote events)

	local onShootEvent = NetworkService:Get("OnShoot", "Gun") -- get shoot remote event
	onShootEvent:FireServer(tool, hitPos) -- To prevent hacking, sending a hit pos instead of the character.
	tool:SetAttribute("Ammo", tool:GetAttribute("Ammo") - 1) -- decrease the ammo. It will also be decreased from the server.
end

local function Reload(gun: Tool, reloadTrack: AnimationTrack) -- reload
	if Reloading then -- if reloading now, (Prevent reloading while reloading)
		return -- skip
	end
	Reloading = true
	DisableShooting()
	reloadTrack.Priority = Enum.AnimationPriority.Action2
	reloadTrack.Looped = false
	reloadTrack:Play(0)

	reloadTrack.Ended:Once( -- to prevent memory leak, used :Once() instead of :Connect() / when reloading anim ended, fill ammos
		function() -- When reloading ended,
			local onReloadEvent = NetworkService:Get("OnReload", "Gun") -- get the remote
			local maxAmmo = GunUtil.GetInfo(gun).MaxAmmo -- get the gun's max ammo
			gun:SetAttribute("Ammo", maxAmmo) -- refill the ammo (fast syncing for client)
			onReloadEvent:FireServer(gun) -- also fill the ammo from the server.
			EnableShooting()
			Reloading = false
		end
	)
end

--- Character Follows The Cursor.
local function moveBodyToCursor(character: Model, trove: typeof(Trove.new())) -- this function rotates the humanoidRootPart to aiming position
	local hit = mouse.Hit -- get world mouse CFrame
	local hitPos = hit.Position -- get the mouse's hit position
	local humanoidRootPart: Part? = character:FindFirstChild("HumanoidRootPart") -- get character's humanoidRootPart
	if humanoidRootPart == nil then -- if failed to find the HumanoidRootPart, return (error preventeing)
		return
	end
	-- Torso Moving
	local characterPos = humanoidRootPart.Position
	local flatTargetPos = Vector3.new(hitPos.X, characterPos.Y, hitPos.Z) -- removed y position.
	local LookAt = CFrame.lookAt(characterPos, flatTargetPos) -- get the final CFrame
	local humanoid = CharacterController:GetHumanoid()

	if humanoid.Health > 0 and humanoid.SeatPart == nil then -- If can rotate the humanoidRootpart,
		humanoidRootPart:PivotTo(LookAt) -- make the character look at the cursor
	end

	-- Head and arms Moving
	GunUtil.BodyLookThere(character, hitPos, trove) -- this method also used by the server. That's why that it is not the local function.
end

------------ GUN MAIN -------------

--- Enable Aiming on gun equip
local function LinkAiming(humanoid: Humanoid)
	local AimInput = InputController:GetAction("Gun", "Aim") -- get the aiming input.

	UnequipTrove:Add(AimInput.Pressed:Connect(function() -- on aiming input pressed, zoom in the camera (start holding)
		ZoomInCamera(humanoid)
	end))
	UnequipTrove:Add(AimInput.Released:Connect(function() -- on aiming input released, zoom in the camera (stop holding)
		ZoomOutCamera(humanoid)
	end))
end

--- Enable Shooting on gun equip
local function LinkShooting(tool: Tool, gunInfo: typeof(GunUtil.GetInfo()), animator: Animator)
	Shooting = false
	local ShootInput = InputController:GetAction("Gun", "Shoot")
	UnequipTrove:Add(ShootInput.Pressed:Connect(function() -- on Shoot Input pressed (start holding)
		if CanShoot then -- if the player can shoot
			Shooting = true -- start shooting
		end
	end))
	UnequipTrove:Add(ShootInput.Released:Connect(function() -- on shoot input released (stop holding)
		Shooting = false -- stop shooting
	end))

	-- if there's no "ammo" attribute, reset it
	if tool:GetAttribute("Ammo") == nil then -- if failed to find the ammo attribute,
		tool:SetAttribute("Ammo", gunInfo.MaxAmmo) -- fill the ammo. (While shooting, server also fills the ammo when there's no "Ammo" attribute. So don't care about that the client only has "Ammo" attribute)
	end

	-- shoot loop
	UnequipTrove:Add(task.spawn(function() -- add a loop that will be destroyed on weapon unequip.
		local shootAnim = GunUtil.GetAnimationSet(tool).Shoot -- get a shooting animation. It is also used in server so its code is shared.
		local shootTrack = animator:LoadAnimation(shootAnim) -- load the anim

		while true do -- shooting loop. To support holding mechanic, used a loop. Every interval, if the player holding 'shoot input', shoot.
			task.wait() -- wait for a bit. To prevent error.
			if Shooting and CanShoot and tool:GetAttribute("Ammo") > 0 then -- If the player can shoot
				Shoot(tool, shootTrack)
				task.wait(gunInfo.FireRate) -- weapon cooldown
			end
		end
	end))
end

--- Enable Reloading on gun equip
local function LinkReload(tool: Tool, animator: Animator)
	-- Get input, anim and load the anim.
	local ReloadInput = InputController:GetAction("Gun", "Reload")
	local reloadAnim = GunUtil.GetAnimationSet(tool).reload
	local reloadTrack = animator:LoadAnimation(reloadAnim)

	UnequipTrove:Add(ReloadInput.Released:Connect(function() -- on reload input activated
		Reload(tool, reloadTrack) -- reload.
	end))
end

-- Enable body aiming on gun equip
local function LinkBodyAiming(tool: Tool)
	-- Set up
	local AttachEvent = NetworkService:Get("Attach", "Gun") -- get the remote. this remote attachs the weapon.

	AnimTrove:Clean() -- Before start to resume animating, stop all gun/weapon anims
	AttachEvent:FireServer(tool) -- attach the gun to the arm.

	-- Character Rotating
	local character = CharacterController:GetCharacter()
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
	if not tool:HasTag("gun") then -- if the weapon is not a gun then return
		return
	end

	AnimTrove:Clean() -- stop playing gun animations.

	InputController:EnableContext("Gun") -- Enable the gun inputs.
	local humanoid = CharacterController:GetHumanoid()
	local animator = CharacterController:GetAnimator()
	local gunInfo = GunUtil.GetInfo(tool) -- get the gun info. Like damage, fireRate and more.

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
		AnimTrove:Clean() -- stop playing gun animations
		-- There's no cleaning unequip trove because.. IDK it works well without it
	end))

	-- Animations
	local anims = GunUtil.GetAnimationSet(tool) -- get gun animations
	local animator = humanoid:FindFirstChildOfClass("Animator")
	PlayGunAnim(humanoid, animator, anims, AnimTrove) -- play the gun movement animations.
end

--- On Gun Unequip
local function OnGunUnequip(tool: Tool)
	if not tool:HasTag("gun") then -- if the tool is not a gun then return
		return
	end

	UnequipTrove:Clean() -- end the gun life cycle
	AnimTrove:Clean() -- stop the animation

	InputController:DisableContext("Gun") -- disable gun inputs
	local UnattachEvent = NetworkService:Get("Unattach", "Weapon")

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
			OnGunEquip(tool)
		end
	end)

	-- On Gun Unequip
	ToolController.OnUnEquip:Connect(function(tool) -- when the tool unequipped
		if tool:HasTag("gun") then -- if the tool is the gun
			OnGunUnequip(tool) -- call the function
		end
	end)

	-- On Kill
	local OnKillEvent = NetworkService:Get("OnKill", "Gun")
	OnKillEvent.OnClientEvent:Connect(function() -- when the player killed someone,
		ReplicatedStorage.Sounds.Combat.GunKill:Play() -- play the kill sound
	end)
end

return GunController
