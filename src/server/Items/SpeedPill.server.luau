-- Server-authoritative SpeedPill handler.
-- On use: grants infinite stamina + bonus move speed for a duration by writing
-- player attributes that SprintController already reacts to.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)
local config = require(ReplicatedStorage.Shared.Items.Actives.SpeedPill)

local cooldowns = {} -- [userId] = lastUseTime
local activeEffects = {} -- [userId] = true while the buff is running

ReplicatedStorage.Remotes.UseSpeedPill.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Cooldown
	local now = tick()
	local last = cooldowns[player.UserId] or 0
	if (now - last) < config.cooldown then return end
	-- Don't stack — reject if already active
	if activeEffects[player.UserId] then return end

	-- Check uses remaining on the tool
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= "SpeedPill" then return end
	local usesValue = tool:FindFirstChild("UsesValue")
	if usesValue and usesValue.Value <= 0 then return end

	cooldowns[player.UserId] = now

	-- Decrement uses
	if usesValue then
		usesValue.Value = usesValue.Value - 1
	end
	activeEffects[player.UserId] = true

	-- Apply speed boost via attributes (SprintController reads these live)
	local baseWalk = PlayerStats.walkSpeed
	local baseSprint = PlayerStats.sprintSpeed
	player:SetAttribute("WalkSpeed", baseWalk * (1 + config.bonusSpeedFraction))
	player:SetAttribute("SprintSpeed", baseSprint * (1 + config.bonusSpeedFraction))

	-- Infinite stamina: set drain to 0 so stamina never decreases
	local baseDrain = PlayerStats.staminaDrainRate
	if config.infiniteStamina then
		player:SetAttribute("StaminaDrainRate", 0)
	end

	-- Flag for client UI
	player:SetAttribute("SpeedPillActive", true)

	-- Revert after duration (or if character dies / player leaves)
	task.delay(config.duration, function()
		activeEffects[player.UserId] = nil
		player:SetAttribute("SpeedPillActive", nil)

		-- Only revert if the player still exists and is alive
		if not player.Parent then return end
		player:SetAttribute("WalkSpeed", baseWalk)
		player:SetAttribute("SprintSpeed", baseSprint)
		if config.infiniteStamina then
			player:SetAttribute("StaminaDrainRate", baseDrain)
		end
	end)
end)

-- Clean up on death — revert stats immediately so respawn starts fresh
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		if activeEffects[player.UserId] then
			activeEffects[player.UserId] = nil
			player:SetAttribute("SpeedPillActive", nil)
			player:SetAttribute("WalkSpeed", PlayerStats.walkSpeed)
			player:SetAttribute("SprintSpeed", PlayerStats.sprintSpeed)
			player:SetAttribute("StaminaDrainRate", PlayerStats.staminaDrainRate)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player.UserId] = nil
	activeEffects[player.UserId] = nil
end)
