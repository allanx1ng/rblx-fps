-- Server-authoritative item restocking via ammo box.
-- Resets UsesValue on all item tools in the player's Backpack and Character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local COOLDOWN = 1 -- match client-side ammo box cooldown
local lastRestock = {} -- [userId] = tick

ReplicatedStorage.Remotes.RestockItems.OnServerEvent:Connect(function(player)
	local now = tick()
	if (now - (lastRestock[player.UserId] or 0)) < COOLDOWN then return end
	lastRestock[player.UserId] = now

	local containers = { player:FindFirstChild("Backpack"), player.Character }
	for _, container in containers do
		if not container then continue end
		for _, tool in container:GetChildren() do
			if not tool:IsA("Tool") then continue end
			local usesValue = tool:FindFirstChild("UsesValue")
			local maxUsesValue = tool:FindFirstChild("MaxUsesValue")
			if usesValue and maxUsesValue then
				usesValue.Value = maxUsesValue.Value
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRestock[player.UserId] = nil
end)
