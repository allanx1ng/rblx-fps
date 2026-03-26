local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local DataStoreService = game:GetService("DataStoreService")
-- local MarketplaceService = game:GetService("MarketplaceService")

local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)

-- ---------------------------------------------------------------------------
-- Game Pass IDs — fill these in when you create the passes on the Creator Hub
-- ---------------------------------------------------------------------------
-- local PASS_IDS = {
-- 	speedBoost  = 0,  -- e.g. +10 sprint speed
-- 	extraHealth = 0,  -- e.g. +50 max health
-- }

-- ---------------------------------------------------------------------------
-- DataStore — stores per-player stat bonuses that accumulate over time
-- (permanent potions, stat points, etc.)
-- ---------------------------------------------------------------------------
-- local statBonusStore = DataStoreService:GetDataStore("StatBonuses_v1")

-- local function loadBonuses(player)
-- 	local success, data = pcall(function()
-- 		return statBonusStore:GetAsync(tostring(player.UserId))
-- 	end)
-- 	if success and data then
-- 		return data
-- 	end
-- 	-- Return empty bonuses on failure or first join
-- 	return {
-- 		walkSpeed   = 0,
-- 		sprintSpeed = 0,
-- 		maxHealth   = 0,
-- 		maxStamina  = 0,
-- 	}
-- end

-- local function saveBonuses(player, bonuses)
-- 	local success, err = pcall(function()
-- 		statBonusStore:SetAsync(tostring(player.UserId), bonuses)
-- 	end)
-- 	if not success then
-- 		warn("Failed to save bonuses for", player.Name, ":", err)
-- 	end
-- end

-- ---------------------------------------------------------------------------
-- Gamepass checks — runs once on join, re-runs after a purchase this session
-- ---------------------------------------------------------------------------
-- local function getGamepassBonuses(player)
-- 	local bonuses = {}
--
-- 	local ok, ownsSpeed = pcall(function()
-- 		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, PASS_IDS.speedBoost)
-- 	end)
-- 	bonuses.sprintSpeed = (ok and ownsSpeed) and 10 or 0
--
-- 	local ok2, ownsHealth = pcall(function()
-- 		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, PASS_IDS.extraHealth)
-- 	end)
-- 	bonuses.maxHealth = (ok2 and ownsHealth) and 50 or 0
--
-- 	return bonuses
-- end

-- ---------------------------------------------------------------------------
-- Applies final stats to the player: defaults + saved bonuses + pass bonuses
-- ---------------------------------------------------------------------------
-- local function applyStats(player, savedBonuses, passBonuses)
-- 	player:SetAttribute("WalkSpeed",         PlayerStats.walkSpeed   + (savedBonuses.walkSpeed   or 0))
-- 	player:SetAttribute("SprintSpeed",       PlayerStats.sprintSpeed + (savedBonuses.sprintSpeed or 0) + (passBonuses.sprintSpeed or 0))
-- 	player:SetAttribute("MaxHealth",         PlayerStats.maxHealth   + (savedBonuses.maxHealth   or 0) + (passBonuses.maxHealth   or 0))
-- 	player:SetAttribute("HealthRegenRate",   PlayerStats.healthRegenRate)
-- 	player:SetAttribute("HealthRegenDelay",  PlayerStats.healthRegenDelay)
-- 	player:SetAttribute("MaxStamina",        PlayerStats.maxStamina  + (savedBonuses.maxStamina  or 0))
-- 	player:SetAttribute("StaminaDrainRate",  PlayerStats.staminaDrainRate)
-- 	player:SetAttribute("StaminaRegenRate",  PlayerStats.staminaRegenRate)
-- 	player:SetAttribute("StaminaRegenDelay", PlayerStats.staminaRegenDelay)
-- 	player:SetAttribute("CrouchSpeed",       PlayerStats.crouchSpeed)
-- end

-- ---------------------------------------------------------------------------
-- Player setup — runs on every join
-- ---------------------------------------------------------------------------
local function onPlayerAdded(player)
	-- Uncomment below once DataStore and gamepass checks are ready.
	-- Until then, SprintController initialises attributes from defaults client-side.

	-- local savedBonuses  = loadBonuses(player)
	-- local passBonuses   = getGamepassBonuses(player)
	-- applyStats(player, savedBonuses, passBonuses)
end

-- ---------------------------------------------------------------------------
-- Mid-session purchases — re-apply stats immediately after a pass is bought
-- ---------------------------------------------------------------------------
-- MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
-- 	if not wasPurchased then return end
-- 	local savedBonuses = loadBonuses(player)
-- 	local passBonuses  = getGamepassBonuses(player)
-- 	applyStats(player, savedBonuses, passBonuses)
-- end)

-- ---------------------------------------------------------------------------
-- Save on leave
-- ---------------------------------------------------------------------------
-- Players.PlayerRemoving:Connect(function(player)
-- 	-- Retrieve the bonuses you've been tracking this session and save them.
-- 	-- e.g. saveBonuses(player, currentBonuses[player])
-- end)

Players.PlayerAdded:Connect(onPlayerAdded)
