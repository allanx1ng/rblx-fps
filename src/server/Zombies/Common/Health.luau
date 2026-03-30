--Responsible for regening a zombie's humanoid's health

local Module = {}

function Module.Initialize(zombieModel, maxHealth)
	local Humanoid = zombieModel:WaitForChild("Zombie")
	local regening = false

	if maxHealth then
		Humanoid.MaxHealth = maxHealth
		Humanoid.Health = maxHealth
	end

	-- regeneration
	local function regenHealth()
		if regening then return end
		regening = true

		while Humanoid.Health < Humanoid.MaxHealth do
			local s = task.wait(1)
			local health = Humanoid.Health
			if health > 0 and health < Humanoid.MaxHealth then
				local newHealthDelta = 0.01 * s * Humanoid.MaxHealth
				health = health + newHealthDelta
				Humanoid.Health = math.min(health, Humanoid.MaxHealth)
			end
		end

		if Humanoid.Health > Humanoid.MaxHealth then
			Humanoid.Health = Humanoid.MaxHealth
		end

		regening = false
	end

	Humanoid.HealthChanged:Connect(regenHealth)
end

return Module
