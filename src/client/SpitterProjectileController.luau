local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local SpitterSpit = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SpitterSpit")

local PROJECTILE_SPEED = 50
local MAX_DISTANCE     = 80

SpitterSpit.OnClientEvent:Connect(function(origin, direction, speed)
	local ball = Instance.new("Part")
	ball.Name = "SpitterSpit"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.8, 0.8, 0.8)
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(50, 205, 50)
	ball.CanCollide = false
	ball.CastShadow = false
	ball.Anchored = false
	ball.CFrame = CFrame.new(origin)
	ball.Parent = workspace

	local bv = Instance.new("BodyVelocity")
	bv.Velocity = direction * (speed or PROJECTILE_SPEED)
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Parent = ball

	Debris:AddItem(ball, MAX_DISTANCE / PROJECTILE_SPEED)
end)

return true
