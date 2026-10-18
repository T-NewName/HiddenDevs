local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunClass = require(ReplicatedStorage.Class.GunClass)
local AR = GunClass.new()

-- CONFIGURES --
AR.Damage = 10
AR.FireRate = 0.12

return AR
