local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunClass = {}
GunClass.__index = GunClass

-------------------------------------------------
-- TYPE
-------------------------------------------------
export type GunClass = {
	FireRate: number,
	Damage: number,
	MaxAmmo: number,

	Bullet: Beam,
	BulletRemainTime: number,
}

-------------------------------------------------
-- PUBLIC API
-------------------------------------------------

function GunClass.new(): GunClass
	local self = setmetatable({}, GunClass)

	-- Gun Default
	self.FireRate = 0.12
	self.Damage = 4
	self.MaxAmmo = 30

	-- Visual
	self.Bullet = ReplicatedStorage.Assets.Bullets.Default
	self.BulletRemainTime = 0.02

	return self
end

return GunClass
