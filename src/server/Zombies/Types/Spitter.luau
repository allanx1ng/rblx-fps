local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpitterSpit = ReplicatedStorage.Remotes.SpitterSpit

local SPIT_COOLDOWN    = 4    -- seconds between shots
local SPIT_RANGE       = 40   -- max range to target a player (studs)
local PROJECTILE_SPEED = 50   -- studs/sec (must match client constant)
local STEP_INTERVAL    = 0.1  -- seconds between raycast steps
local MAX_DISTANCE     = 80   -- studs before projectile expires

local Module = {}

local function findNearestPlayer(origin)
	local nearest, nearestDist = nil, SPIT_RANGE
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then continue end
		local dist = (hrp.Position - origin).Magnitude
		if dist < nearestDist then
			nearest = player
			nearestDist = dist
		end
	end
	return nearest
end

local function buildRaycastParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged("Enemy_Zombie")
	return params
end

local function simulateProjectile(origin, direction, damage)
	local params = buildRaycastParams()
	local stepDist = PROJECTILE_SPEED * STEP_INTERVAL
	local pos = origin
	local traveled = 0

	while traveled < MAX_DISTANCE do
		task.wait(STEP_INTERVAL)
		local result = workspace:Raycast(pos, direction * stepDist, params)
		if result then
			local ancestor = result.Instance:FindFirstAncestorOfClass("Model")
			if ancestor then
				local humanoid = ancestor:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					local player = Players:GetPlayerFromCharacter(ancestor)
					if player then
						humanoid:TakeDamage(damage)
					end
				end
			end
			return
		end
		pos = pos + direction * stepDist
		traveled = traveled + stepDist
	end
end

function Module.Initialize(zombieModel)
	local humanoid = zombieModel:WaitForChild("Zombie")
	humanoid.WalkSpeed = zombieModel:GetAttribute("WalkSpeed") or 8

	local damage = zombieModel:GetAttribute("Damage") or 15

	task.spawn(function()
		while humanoid and humanoid.Parent and humanoid.Health > 0 do
			task.wait(SPIT_COOLDOWN)
			if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then break end

			local hrp = zombieModel:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end

			local target = findNearestPlayer(hrp.Position)
			if not target then continue end

			local targetHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if not targetHRP then continue end

			local origin = hrp.Position + Vector3.new(0, 1, 0)
			local direction = (targetHRP.Position - origin).Unit

			SpitterSpit:FireAllClients(origin, direction, PROJECTILE_SPEED)
			task.spawn(simulateProjectile, origin, direction, damage)
		end
	end)
end

return Module
