local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
-- local DataStoreService = game:GetService("DataStoreService")
-- local MarketplaceService = game:GetService("MarketplaceService")

local ServerStorage = game:GetService("ServerStorage")

local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)
local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)
local ItemRegistry = require(ReplicatedStorage.Shared.ItemRegistry)
local Guns = ReplicatedStorage.Shared.Guns
local ActiveItems = ReplicatedStorage.Shared.Items.Actives
local WeaponTools = ServerStorage:WaitForChild("WeaponTools")

-- ---------------------------------------------------------------------------
-- Damage multipliers by body part name (works for both R6 and R15)
-- ---------------------------------------------------------------------------
local TORSO_PARTS = {
	Torso = true,
	UpperTorso = true,
	LowerTorso = true,
	HumanoidRootPart = true,  -- often what raycasts actually hit
}

local function getMultiplier(partName, config)
	if partName == "Head" then
		return config.headshotMultiplier or 1
	elseif TORSO_PARTS[partName] then
		return 1
	else
		return config.limbMultiplier or 1  -- arms, legs
	end
end

ReplicatedStorage.Remotes.FireProjectile.OnServerEvent:Connect(function(shooter, origin, direction, gunName)
	local shooterCharacter = shooter.Character
	if not shooterCharacter then return end
	local shooterHRP = shooterCharacter:FindFirstChild("HumanoidRootPart")
	if not shooterHRP then return end
	if (origin - shooterHRP.Position).Magnitude > 20 then return end

	local configModule = Guns:FindFirstChild(gunName)
	if not configModule then return end
	local config = require(configModule)
	if config.firingMode ~= "projectile" then return end

	local speed = config.projectileSpeed or 160
	local size  = config.projectileSize  or Vector3.new(0.2, 0.2, 3)
	local color = config.projectileColor or Color3.fromRGB(0, 255, 255)

	local projectile = Instance.new("Part")
	projectile.Name = "Projectile"
	projectile.Size = size
	projectile.Color = color
	projectile.Material = Enum.Material.Neon
	projectile.Transparency = 0
	projectile.CanCollide = false
	projectile.CastShadow = false
	projectile:SetAttribute("ShooterUserId", shooter.UserId)
	projectile.CFrame = CFrame.new(origin, origin + direction)
		* CFrame.new(0, 0, -size.Z / 2)

	if config.projectileLight then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = config.projectileLightBrightness or 1
		light.Range = config.projectileLightRange or 16
		light.Parent = projectile
	end

	local bv = Instance.new("BodyVelocity")
	bv.Velocity = direction * speed
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Parent = projectile

	projectile.Parent = workspace
	Debris:AddItem(projectile, (config.range or 500) / speed)

	local hasHit = false
	projectile.Touched:Connect(function(otherPart)
		if hasHit then return end
		if not otherPart or not otherPart.Parent then return end
		if otherPart:IsDescendantOf(shooterCharacter) then return end

		local victimCharacter = otherPart:FindFirstAncestorOfClass("Model")
		local humanoid = victimCharacter and victimCharacter:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		local victim = Players:GetPlayerFromCharacter(victimCharacter)
		if victim == shooter then return end

		hasHit = true
		projectile:Destroy()
		humanoid:TakeDamage(config.damage * getMultiplier(otherPart.Name, config))
	end)
end)

ReplicatedStorage.Remotes.DealDamage.OnServerEvent:Connect(function(shooter, hitPart)
	-- Basic sanity checks on the incoming data
	if not hitPart or not hitPart:IsA("BasePart") then return end

	local victimCharacter = hitPart:FindFirstAncestorOfClass("Model")
	if not victimCharacter then return end

	local humanoid = victimCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Prevent self-damage
	local victim = Players:GetPlayerFromCharacter(victimCharacter)
	if victim == shooter then return end

	-- Shooter must be alive with a character
	local shooterCharacter = shooter.Character
	if not shooterCharacter then return end
	local shooterHRP = shooterCharacter:FindFirstChild("HumanoidRootPart")
	local victimHRP  = victimCharacter:FindFirstChild("HumanoidRootPart")
	if not shooterHRP or not victimHRP then return end

	-- Find the shooter's equipped tool and load its server-side config
	local tool = shooterCharacter:FindFirstChildOfClass("Tool")
	if not tool then return end

	local configModule = Guns:FindFirstChild(tool.Name)
	if not configModule then return end
	local config = require(configModule)

	-- Distance sanity check with generous latency tolerance
	local distance = (shooterHRP.Position - victimHRP.Position).Magnitude
	if distance > (config.range or 500) * 1.5 then return end

	local damage = config.damage * getMultiplier(hitPart.Name, config)
	humanoid:TakeDamage(damage)
end)

-- ---------------------------------------------------------------------------
-- Healing Potion — server-authoritative healing with cooldown enforcement
-- ---------------------------------------------------------------------------
local healingCooldowns = {} -- [player] = lastUseTime per potion name

ReplicatedStorage.Remotes.UseHealingPotion.OnServerEvent:Connect(function(player, potionName)
	print('using health potion')
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local configModule = ActiveItems:FindFirstChild(potionName)
	if not configModule then return end
	local config = require(configModule)

	-- Enforce server-side cooldown
	local key = player.UserId .. "_" .. potionName
	local lastUse = healingCooldowns[key] or 0
	if tick() - lastUse < config.cooldown then return end
	healingCooldowns[key] = tick()

	-- Apply healing
	if config.healToFull then
		humanoid.Health = humanoid.MaxHealth
	else
		humanoid.Health = math.min(humanoid.Health + (config.healAmount or 0), humanoid.MaxHealth)
	end
end)

-- Clean up cooldown entries when a player leaves
Players.PlayerRemoving:Connect(function(player)
	for key in healingCooldowns do
		if string.find(key, tostring(player.UserId) .. "_") == 1 then
			healingCooldowns[key] = nil
		end
	end
end)

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
-- Inventory / loadout — server-authoritative slot management
-- ---------------------------------------------------------------------------
-- Slots: primary (1), secondary (2), item1 (4), item2 (5)
-- ActiveSlot attribute tracks which slot the player currently has in-hand.
local VALID_SLOTS = { primary = true, secondary = true, item1 = true, item2 = true }

-- Build a lookup: weaponName -> slot, for validation
local weaponSlotLookup = {}
for slot, weapons in WeaponRegistry do
	for _, entry in weapons do
		weaponSlotLookup[entry.name] = slot
	end
end

-- Build item lookup from ItemRegistry
local VALID_ITEMS = {}
for _, entry in ItemRegistry do
	VALID_ITEMS[entry.name] = true
end

-- Find a tool belonging to a slot in backpack or character
local function findSlotTool(player, slot)
	local function searchIn(container)
		if not container then return nil end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("Slot") == slot then
				return child
			end
		end
		return nil
	end
	return searchIn(player.Character) or searchIn(player:FindFirstChild("Backpack"))
end

-- Remove any tool in the player's backpack/character that belongs to the given slot
local function clearSlotTool(player, slot)
	local function removeIfSlot(container)
		if not container then return end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("Slot") == slot then
				child:Destroy()
			end
		end
	end
	removeIfSlot(player:FindFirstChild("Backpack"))
	removeIfSlot(player.Character)
end

-- Clone a tool from ServerStorage into the player's backpack
local function grantTool(player, toolName, slot)
	local template = WeaponTools:FindFirstChild(toolName)
	if not template then return end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local tool = template:Clone()
	tool:SetAttribute("Slot", slot)
	tool.Parent = backpack
end

-- Put a specific slot's tool into the player's hand
local function equipSlotTool(player, slot)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local tool = findSlotTool(player, slot)
	if not tool then return end

	-- If tool is already in character, it's already equipped
	if tool.Parent == character then return end

	humanoid:UnequipTools()
	humanoid:EquipTool(tool)
end

-- SelectSlot: client presses 1-5, server equips the corresponding slot
ReplicatedStorage.Remotes.SelectSlot.OnServerEvent:Connect(function(player, slot)
	if not VALID_SLOTS[slot] then return end

	-- Nothing assigned to this slot
	local equippedName = player:GetAttribute("Equipped_" .. slot)
	if not equippedName then return end

	local activeSlot = player:GetAttribute("ActiveSlot")

	if activeSlot == slot then
		-- Already holding this slot — do nothing (same key press)
		return
	end

	-- Switch to this slot
	player:SetAttribute("ActiveSlot", slot)
	equipSlotTool(player, slot)
end)

-- EquipWeapon: loadout UI assigns a weapon/item to a slot
ReplicatedStorage.Remotes.EquipWeapon.OnServerEvent:Connect(function(player, slot, weaponName)
	if not VALID_SLOTS[slot] then return end

	local wasActiveSlot = player:GetAttribute("ActiveSlot") == slot

	-- Clear existing tool in that slot
	clearSlotTool(player, slot)

	if weaponName == nil then
		-- Unequip: clear the attribute
		player:SetAttribute("Equipped_" .. slot, nil)
		if wasActiveSlot then
			player:SetAttribute("ActiveSlot", nil)
		end
		return
	end

	-- Validate: weapons must match their registry slot, items must be in VALID_ITEMS
	if slot == "primary" or slot == "secondary" then
		if weaponSlotLookup[weaponName] ~= slot then return end
	elseif slot == "item1" or slot == "item2" then
		if not VALID_ITEMS[weaponName] then return end
	end

	-- Grant the tool and record it
	player:SetAttribute("Equipped_" .. slot, weaponName)
	grantTool(player, weaponName, slot)

	-- If the player was holding this slot, auto-equip the new tool into hand
	if wasActiveSlot then
		equipSlotTool(player, slot)
	end
end)

-- ---------------------------------------------------------------------------
-- Custom health regen — replaces the default Roblox "Health" script
-- ---------------------------------------------------------------------------
local function startHealthRegen(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Remove the default Roblox health regen script
	local defaultHealthScript = character:FindFirstChild("Health")
	if defaultHealthScript then
		defaultHealthScript:Destroy()
	end

	task.spawn(function()
		local lastDamageTime = 0

		local conn = humanoid.HealthChanged:Connect(function(newHealth)
			-- Health went down → record damage time
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

-- ---------------------------------------------------------------------------
-- Player setup — runs on every join
-- ---------------------------------------------------------------------------
local function regrantEquippedTools(player)
	for slot in VALID_SLOTS do
		local toolName = player:GetAttribute("Equipped_" .. slot)
		if toolName then
			grantTool(player, toolName, slot)
		end
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		startHealthRegen(character)
		-- Re-grant equipped weapons after respawn (Backpack is cleared on spawn)
		regrantEquippedTools(player)
	end)

	-- Handle already-spawned character (e.g. if PlayerAdded fires late)
	if player.Character then
		startHealthRegen(player.Character)
		regrantEquippedTools(player)
	end
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
