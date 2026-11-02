local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunUtil = {}

local Config = ReplicatedStorage.Config.Gun

local GunClass = require(ReplicatedStorage.Class.GunClass)
local Trove = require(ReplicatedStorage.Packages.Trove)

--- Get gun's config
function GunUtil.GetInfo(gun: Tool): GunClass.GunClass?
	if not gun:IsA("Tool") then
		warn("No Gun Config Found! : ", gun.Name)
		return
	end

	local name = gun.Name
	return require(Config:FindFirstChild(name))
end

--- Get gun's muzzle attachment
function GunUtil.GetMuzzle(gun: Tool): Attachment?
	if gun:FindFirstChild("Attachments") == nil then
		warn("Failed TO Find The Muzzle")
		return nil
	end
	return gun:FindFirstChild("Attachments"):FindFirstChild("Muzzle")
end

--- Show gun bullet visual. ONLY VISUAL
function GunUtil.ShowBullet(gun: Tool, hitPos: Vector3)
	local gunInfo = GunUtil.GetInfo(gun)
	local muzzle = GunUtil.GetMuzzle(gun)
	local bullet = gunInfo.Bullet:Clone()
	local hitAttach = Instance.new("Attachment")
	hitAttach.Parent = workspace
	hitAttach.WorldPosition = hitPos

	bullet.Attachment0 = muzzle
	bullet.Attachment1 = hitAttach

	bullet.Parent = workspace
	Debris:AddItem(hitAttach, gunInfo.BulletRemainTime)
	Debris:AddItem(bullet, gunInfo.BulletRemainTime)
end

-- Neck's default Orientation
local dx = -90
local dy = 0
local dz = 180

-- Arm's default Orientation
local left_y = -90
local right_y = 90

function GunUtil.ResetBody(character: Model)
	local Torso: Part = character:FindFirstChild("Torso") or character:WaitForChild("Torso")
	local Neck: Motor6D = Torso:FindFirstChild("Neck") or Torso:WaitForChild("Neck")
	local LeftShoulder: Motor6D = Torso:FindFirstChild("Left Shoulder") or Torso:WaitForChild("Left Shoulder")
	local RightShoulder: Motor6D = Torso:FindFirstChild("Right Shoulder") or Torso:WaitForChild("Right Shoulder")

	Neck.C0 = CFrame.new(Neck.C0.Position) * CFrame.Angles(math.rad(dx), math.rad(dy), math.rad(dz))
	RightShoulder.C0 = CFrame.new(RightShoulder.C0.Position) * CFrame.Angles(0, math.rad(right_y), 0)
	LeftShoulder.C0 = CFrame.new(LeftShoulder.C0.Position) * CFrame.Angles(0, math.rad(left_y), 0)
end

--- Rotate arms and heads to look at there
function GunUtil.BodyLookThere(character: Model, hitPos: Vector3, trove: typeof(Trove.new())?)
	local Torso: Part = character:FindFirstChild("Torso") or character:WaitForChild("Torso")
	local Head: Part = character:FindFirstChild("Head") or character:WaitForChild("Head")
	local Neck: Motor6D = Torso:FindFirstChild("Neck") or Torso:WaitForChild("Neck")
	local LeftShoulder: Motor6D = Torso:FindFirstChild("Left Shoulder") or Torso:WaitForChild("Left Shoulder")
	local RightShoulder: Motor6D = Torso:FindFirstChild("Right Shoulder") or Torso:WaitForChild("Right Shoulder")

	local x, y, z = CFrame.lookAt(Head.Position, hitPos):ToOrientation()
	x *= 0.75

	Neck.C0 = CFrame.new(Neck.C0.Position) * CFrame.Angles(math.rad(dx) + x, math.rad(dy), math.rad(dz))
	RightShoulder.C0 = CFrame.new(RightShoulder.C0.Position) * CFrame.Angles(0, math.rad(right_y), x)
	LeftShoulder.C0 = CFrame.new(LeftShoulder.C0.Position) * CFrame.Angles(0, math.rad(left_y), -x)

	if trove ~= nil then
		trove:Add(function()
			GunUtil.ResetBody(character)
		end)
	end
end

--- Get Weapon's animation set
function GunUtil.GetAnimationSet(tool: Tool): { [string]: Animation }
	local animFolder = ReplicatedStorage.Animations.Weapon
	if tool:HasTag("gun") then
		animFolder = animFolder.Gun
	end

	animFolder = animFolder:FindFirstChild(tool.Name)

	local animations = {}
	for _, v in ipairs(animFolder:GetChildren()) do
		if v:IsA("Animation") then
			animations[v.Name] = v
		end
	end

	return animations :: { [string]: Animation }
end

return GunUtil
