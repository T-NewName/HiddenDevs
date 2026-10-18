local RayUtil = {}

--- By AI. I'm lazy to code this.
function RayUtil.Visualize(origin: Vector3, direction: Vector3, hitPosition: Vector3)
	-- If something was hit, use the hit position for length; otherwise use full direction
	local targetPos = hitPosition or (origin + direction)
	local distance = (targetPos - origin).Magnitude
	local midpoint = origin + (targetPos - origin) / 2

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 0, 0)
	part.CanQuery = false

	-- Set size (thin X and Y, length on Z axis)
	part.Size = Vector3.new(0.1, 0.1, distance)
	part.CFrame = CFrame.lookAt(midpoint, targetPos)
	part.Parent = workspace

	-- Remove the part quickly so it acts like a temporary debug line
	task.delay(1, function()
		part:Destroy()
	end)
end

return RayUtil
