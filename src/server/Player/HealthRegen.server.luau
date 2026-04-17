-- Custom health regen — replaces the default Roblox "Health" script with
-- delay-after-damage regen tuned by PlayerStats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)

local function startHealthRegen(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local defaultHealthScript = character:FindFirstChild("Health")
	if defaultHealthScript then
		defaultHealthScript:Destroy()
	end

	task.spawn(function()
		local lastDamageTime = 0

		local conn = humanoid.HealthChanged:Connect(function(newHealth)
			if newHealth < humanoid.MaxHealth then
				lastDamageTime = tick()
			end
		end)

		while humanoid and humanoid.Parent and humanoid.Health > 0 do
			task.wait(1)
			if tick() - lastDamageTime >= PlayerStats.healthRegenDelay then
				if humanoid and humanoid.Parent and humanoid.Health > 0 then
					humanoid.Health = math.min(humanoid.Health + PlayerStats.healthRegenRate, humanoid.MaxHealth)
				end
			end
		end

		conn:Disconnect()
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(startHealthRegen)
	if player.Character then
		startHealthRegen(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end
