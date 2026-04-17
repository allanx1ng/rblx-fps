-- Applies equipped passive buffs to player stats.
--
-- Each buff slot (buff1, buff2, ...) holds the name of an equipped buff config
-- from ReplicatedStorage.Shared.Buffs. This script reads those slots, sums the
-- bonuses, and writes the resulting stats to player attributes / Humanoid props.
--
-- Stats currently driven from buff configs:
--   bonusMaxHealth — added to Humanoid.MaxHealth (preserves health ratio)
--
-- Triggers a recompute on:
--   * any Equipped_buff* attribute change
--   * CharacterAdded (so a fresh character spawns at the boosted MaxHealth)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buffs = ReplicatedStorage.Shared:WaitForChild("Buffs")

local function loadBuffConfig(name)
	local module = Buffs:FindFirstChild(name)
	if not module then return nil end
	return require(module)
end

local function collectEquippedBuffs(player)
	local result = {}
	for attrName, value in player:GetAttributes() do
		if string.find(attrName, "^Equipped_buff") and type(value) == "string" then
			local config = loadBuffConfig(value)
			if config then
				table.insert(result, config)
			end
		end
	end
	return result
end

local function applyBuffsToCharacter(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local bonusMax = 0
	for _, config in collectEquippedBuffs(player) do
		bonusMax += (config.bonusMaxHealth or 0)
	end

	-- Default Humanoid.MaxHealth is 100 (Roblox standard); add the buff bonus
	-- on top. If we ever introduce a base-MaxHealth attribute, swap 100 for it.
	local newMax = 100 + bonusMax
	if humanoid.MaxHealth == newMax then return end

	-- Preserve current health ratio so toggling a buff mid-life isn't jarring.
	local ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	humanoid.MaxHealth = newMax
	humanoid.Health = math.clamp(ratio * newMax, 0, newMax)
end

local function reapply(player)
	local character = player.Character
	if not character then return end
	applyBuffsToCharacter(player, character)
end

local function onPlayerAdded(player)
	player.AttributeChanged:Connect(function(attr)
		if string.find(attr, "^Equipped_buff") then
			reapply(player)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		-- Wait one frame so the Humanoid finishes initializing before we resize it.
		task.defer(function()
			if character.Parent then
				applyBuffsToCharacter(player, character)
			end
		end)
	end)

	if player.Character then
		applyBuffsToCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end
