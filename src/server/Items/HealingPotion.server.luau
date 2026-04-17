-- Server-authoritative healing potion handler with cooldown enforcement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActiveItems = ReplicatedStorage.Shared.Items.Actives

local cooldowns = {} -- ["<userId>_<potionName>"] = lastUseTime

ReplicatedStorage.Remotes.UseHealingPotion.OnServerEvent:Connect(function(player, potionName)
	print('using health potion')
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local configModule = ActiveItems:FindFirstChild(potionName)
	if not configModule then return end
	local config = require(configModule)

	local key = player.UserId .. "_" .. potionName
	local lastUse = cooldowns[key] or 0
	if tick() - lastUse < config.cooldown then return end
	cooldowns[key] = tick()

	if config.healToFull then
		humanoid.Health = humanoid.MaxHealth
	else
		humanoid.Health = math.min(humanoid.Health + (config.healAmount or 0), humanoid.MaxHealth)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local prefix = tostring(player.UserId) .. "_"
	for key in cooldowns do
		if string.find(key, prefix) == 1 then
			cooldowns[key] = nil
		end
	end
end)
