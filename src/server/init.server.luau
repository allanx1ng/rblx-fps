local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
-- local DataStoreService = game:GetService("DataStoreService")
-- local MarketplaceService = game:GetService("MarketplaceService")

local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

-- ViewModel collision group — collides with nothing, used by client viewmodels
PhysicsService:RegisterCollisionGroup("ViewModel")
PhysicsService:CollisionGroupSetCollidable("ViewModel", "Default", false)

-- Player collision group — players are assigned here so barriers can target them
PhysicsService:RegisterCollisionGroup("PlayerCharacter")
PhysicsService:CollisionGroupSetCollidable("PlayerCharacter", "Default", true)
PhysicsService:CollisionGroupSetCollidable("PlayerCharacter", "PlayerCharacter", true)

-- ZombieBarrier — blocks players, lets everything else (zombies) through
PhysicsService:RegisterCollisionGroup("ZombieBarrier")
PhysicsService:CollisionGroupSetCollidable("ZombieBarrier", "Default", false)           -- zombies pass through
PhysicsService:CollisionGroupSetCollidable("ZombieBarrier", "PlayerCharacter", true)    -- players blocked
PhysicsService:CollisionGroupSetCollidable("ZombieBarrier", "ViewModel", false)

local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)
local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)
local ItemRegistry = require(ReplicatedStorage.Shared.ItemRegistry)
local LevelConfig = require(ReplicatedStorage.Shared.LevelConfig)
local Guns = ReplicatedStorage.Shared.Guns
local Melee = ReplicatedStorage.Shared:WaitForChild("Melee")
local ActiveItems = ReplicatedStorage.Shared.Items.Actives
local WeaponTools = ServerStorage:WaitForChild("WeaponTools")

-- DEBUG: list everything in WeaponTools at startup
print("[WeaponTools] Contents:")
for _, child in WeaponTools:GetChildren() do
	print("  -", child.Name, child.ClassName)
end

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
	if config.firingMode ~= "projectile" and config.firingMode ~= "explosive_projectile" then return end

	local speed = config.projectileSpeed or 160
	local isExplosive = config.firingMode == "explosive_projectile"

	-- Create projectile: clone from ThirdPersonWeapons for explosive, or build from config
	local projectile

	if isExplosive then
		local ThirdPersonWeapons = ReplicatedStorage:FindFirstChild("ThirdPersonWeapons")
		local weaponTemplate = ThirdPersonWeapons and ThirdPersonWeapons:FindFirstChild(gunName)
		local projectileTemplate = weaponTemplate and weaponTemplate:FindFirstChild("Projectile", true)

		if projectileTemplate then
			projectile = projectileTemplate:Clone()
			projectile.Anchored = false
			projectile.CanCollide = false
			projectile.CanTouch = true
			projectile.CanQuery = false
			projectile.CastShadow = false
			for _, child in projectile:GetChildren() do
				if child:IsA("Weld") or child:IsA("WeldConstraint") then child:Destroy() end
			end
		end

		-- Hide warhead on the third-person weapon model
		for _, child in shooterCharacter:GetChildren() do
			if child:IsA("Model") and child.Name == gunName then
				local tpWarhead = child:FindFirstChild("Projectile", true)
				if tpWarhead then
					tpWarhead.Transparency = 1
					for _, c in tpWarhead:GetChildren() do
						if c:IsA("Light") then c.Enabled = false end
					end
					-- Restore after reload
					task.delay(config.reloadTime, function()
						if tpWarhead and tpWarhead.Parent then
							tpWarhead.Transparency = 0
							for _, c in tpWarhead:GetChildren() do
								if c:IsA("Light") then c.Enabled = true end
							end
						end
					end)
				end
				break
			end
		end
	end

	-- Fallback: create generic projectile part
	if not projectile then
		local size  = config.projectileSize  or Vector3.new(0.2, 0.2, 3)
		local color = config.projectileColor or Color3.fromRGB(0, 255, 255)

		projectile = Instance.new("Part")
		projectile.Size = size
		projectile.Color = color
		projectile.Material = isExplosive and Enum.Material.Metal or Enum.Material.Neon
		projectile.CanCollide = false
		projectile.CastShadow = false

		if config.projectileLight then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Brightness = config.projectileLightBrightness or 1
			light.Range = config.projectileLightRange or 16
			light.Parent = projectile
		end
	end

	projectile.Name = "Projectile"
	projectile.Transparency = 0
	projectile.CollisionGroup = "Default"
	projectile:SetAttribute("ShooterUserId", shooter.UserId)
	if isExplosive then
		projectile:SetAttribute("Explosive", true)
	end
	-- Orient so the projectile points in direction of travel
	-- Explosive projectile mesh faces +X when at (0,0,0), so rotate -90° on Y to align with -Z (forward)
	local meshCorrection = isExplosive and CFrame.Angles(0, math.rad(-90), 0) or CFrame.new()
	projectile.CFrame = CFrame.new(origin, origin + direction)
		* CFrame.new(0, 0, -(projectile.Size.Z / 2))
		* meshCorrection

	local bv = Instance.new("BodyVelocity")
	bv.Velocity = direction * speed
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Parent = projectile

	projectile.Parent = workspace
	Debris:AddItem(projectile, (config.range or 500) / speed)

	local hasHit = false
	local armed = false
	task.delay(0.1, function() armed = true end)

	if isExplosive then
		-- Explosive: detonate on any surface (not just characters)
		projectile.Touched:Connect(function(otherPart)
			if hasHit then return end
			if not armed then return end
			if not otherPart or not otherPart.Parent then return end
			if otherPart:IsDescendantOf(shooterCharacter) then return end
			if otherPart.Name == "Projectile" then return end

			hasHit = true
			local explosionPos = projectile.Position
			projectile:Destroy()

			-- Create explosion VFX
			local maxRadius = config.blastTiers[#config.blastTiers].radius
			local explosion = Instance.new("Explosion")
			explosion.Position = explosionPos
			explosion.BlastRadius = maxRadius
			explosion.BlastPressure = 0              -- no physics knockback
			explosion.DestroyJointRadiusPercent = 0   -- no joint breaking
			explosion.Parent = workspace

			-- Explicit explosion sound (Roblox Explosion doesn't reliably play audio)
			local explosionSound = Instance.new("Sound")
			explosionSound.SoundId = "rbxasset://sounds/collide.ogg" -- built-in explosion-like sound
			explosionSound.Volume = 1.5
			explosionSound.RollOffMaxDistance = 200
			-- Anchor a small invisible part at the explosion point for spatial audio
			local soundPart = Instance.new("Part")
			soundPart.Size = Vector3.new(0.1, 0.1, 0.1)
			soundPart.Transparency = 1
			soundPart.Anchored = true
			soundPart.CanCollide = false
			soundPart.CanTouch = false
			soundPart.CanQuery = false
			soundPart.Position = explosionPos
			explosionSound.Parent = soundPart
			soundPart.Parent = workspace
			explosionSound:Play()
			Debris:AddItem(soundPart, 3)

			-- Tiered damage — deduplicate per humanoid
			local damaged = {}
			explosion.Hit:Connect(function(hitPart, distance)
				local victimChar = hitPart:FindFirstAncestorOfClass("Model")
				if not victimChar then return end
				local humanoid = victimChar:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then return end
				if damaged[humanoid] then return end
				-- No friendly fire — only damage NPCs
				if Players:GetPlayerFromCharacter(victimChar) then return end

				-- Find the highest-damage tier that covers this distance
				local dmg = 0
				for _, tier in config.blastTiers do
					if distance <= tier.radius then
						dmg = tier.damage
						break
					end
				end
				if dmg <= 0 then return end

				damaged[humanoid] = true
				humanoid:TakeDamage(dmg)
			end)
		end)
	else
		-- Standard projectile: damage on character hit, with optional piercing
		local maxPierceCount = config.pierceCount or 0
		local pierced = 0
		local damagedHumanoids = {}

		projectile.Touched:Connect(function(otherPart)
			if hasHit then return end
			if not otherPart or not otherPart.Parent then return end
			if otherPart:IsDescendantOf(shooterCharacter) then return end

			local victimCharacter = otherPart:FindFirstAncestorOfClass("Model")
			local humanoid = victimCharacter and victimCharacter:FindFirstChildOfClass("Humanoid")

			if humanoid then
				if humanoid.Health <= 0 then return end
				if damagedHumanoids[humanoid] then return end

				-- No friendly fire — only damage NPCs
				local victim = Players:GetPlayerFromCharacter(victimCharacter)
				if victim then return end

				-- Pierce damage falloff: linearly decreases from 1.0 to 1/(maxPierceCount+1)
				local totalHits = maxPierceCount + 1
				local damageMult = (totalHits - pierced) / totalHits
				damagedHumanoids[humanoid] = true
				humanoid:TakeDamage(config.damage * getMultiplier(otherPart.Name, config) * damageMult)

				pierced += 1
				if pierced > maxPierceCount then
					hasHit = true
					projectile:Destroy()
				end
			else
				-- Hit terrain/wall — stop
				hasHit = true
				projectile:Destroy()
			end
		end)
	end
end)

ReplicatedStorage.Remotes.DealDamage.OnServerEvent:Connect(function(shooter, hitPart, pierceMult)
	-- Basic sanity checks on the incoming data
	if not hitPart or not hitPart:IsA("BasePart") then return end
	-- Clamp pierce multiplier to valid range (untrusted client data)
	if type(pierceMult) ~= "number" then pierceMult = 1 end
	pierceMult = math.clamp(pierceMult, 0, 1)

	local victimCharacter = hitPart:FindFirstAncestorOfClass("Model")
	if not victimCharacter then return end

	local humanoid = victimCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- No friendly fire — only damage NPCs, not players
	local victim = Players:GetPlayerFromCharacter(victimCharacter)
	if victim then return end

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

	local damage = config.damage * getMultiplier(hitPart.Name, config) * pierceMult
	humanoid:TakeDamage(damage)
end)

-- ---------------------------------------------------------------------------
-- Melee — swing animation + damage
-- ---------------------------------------------------------------------------
local meleeSwingRemote = ReplicatedStorage.Remotes:WaitForChild("MeleeSwing")
local meleeDamageRemote = ReplicatedStorage.Remotes:WaitForChild("MeleeDamage")

local lastSwingTime = {} -- [player] -> tick

meleeSwingRemote.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then return end
	local configModule = Melee:FindFirstChild(tool.Name)
	if not configModule then return end
	local config = require(configModule)

	-- Rate limit
	local now = tick()
	local last = lastSwingTime[player] or 0
	if (now - last) < config.swingCooldown * 0.8 then return end
	lastSwingTime[player] = now

	-- Play slash animation on the character's Animator (replicates to all clients)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Load fresh each swing — tracks don't survive character respawn
	local anim = Instance.new("Animation")
	anim.AnimationId = config.slashAnimationId
	print("[MeleeSwing] Playing slash animation:", config.slashAnimationId, "on", player.Name)
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	track:Play()
end)

meleeDamageRemote.OnServerEvent:Connect(function(attacker, hitPart)
	if not hitPart or not hitPart:IsA("BasePart") then return end

	local victimCharacter = hitPart:FindFirstAncestorOfClass("Model")
	if not victimCharacter then return end
	local humanoid = victimCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- No friendly fire — only damage NPCs
	local victim = Players:GetPlayerFromCharacter(victimCharacter)
	if victim then return end

	local attackerCharacter = attacker.Character
	if not attackerCharacter then return end
	local attackerHRP = attackerCharacter:FindFirstChild("HumanoidRootPart")
	local victimHRP = victimCharacter:FindFirstChild("HumanoidRootPart")
	if not attackerHRP or not victimHRP then return end

	local tool = attackerCharacter:FindFirstChildOfClass("Tool")
	if not tool then return end
	local configModule = Melee:FindFirstChild(tool.Name)
	if not configModule then return end
	local config = require(configModule)

	-- Distance check
	local distance = (attackerHRP.Position - victimHRP.Position).Magnitude
	if distance > config.range * 1.5 then return end

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
	reconcilingXP[player] = nil
	lastSwingTime[player] = nil
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
local VALID_SLOTS = { primary = true, secondary = true, melee = true, item1 = true, item2 = true }

-- ---------------------------------------------------------------------------
-- Unlock tracking — per-session weapon ownership
-- ---------------------------------------------------------------------------
-- Unlocked state is stored as player attributes: Unlocked_{weaponName} = true
-- Free weapons (unlockCost == 0 and robuxCost == 0) are auto-unlocked on join.
--
-- TODO: Read persisted unlock data from DataStore here.
--       On player join, load saved unlocks and merge with free defaults.
--       On purchase, save the updated unlock set.
--       On player leave, ensure any pending saves are flushed.

local DEFAULT_GOLD = 999

-- Build set of free weapons (auto-unlocked on join)
local freeWeapons = {}
for _, weapons in WeaponRegistry do
	for _, entry in weapons do
		if (entry.unlockCost or 0) == 0 and (entry.robuxCost or 0) == 0 then
			freeWeapons[entry.name] = true
		end
	end
end

local function initPlayerUnlocks(player)
	-- TODO: Load persisted unlocks from DataStore and apply here.
	--       For now, only free weapons are unlocked on join.
	for weaponName in freeWeapons do
		player:SetAttribute("Unlocked_" .. weaponName, true)
	end
end

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
	print("[grantTool]", toolName, "slot:", slot, "template:", template)
	if not template then return end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local tool = template:Clone()
	tool:SetAttribute("Slot", slot)

	-- Melee tools: clone Handle from ThirdPersonWeapons so Roblox grips it natively
	if Melee:FindFirstChild(toolName) then
		local ThirdPersonWeapons = ReplicatedStorage:FindFirstChild("ThirdPersonWeapons")
		if ThirdPersonWeapons then
			local weaponModel = ThirdPersonWeapons:FindFirstChild(toolName)
			if weaponModel then
				local handle = weaponModel:FindFirstChild("Handle")
				if handle then
					local h = handle:Clone()
					h.Name = "Handle"
					h.Anchored = false
					h.CanCollide = false
					h.Massless = true
					h.Parent = tool
				end
			end
		end
		tool.Grip = CFrame.new(0, 0, -1.7, 0, 0, 1, 1, 0, 0, 0, 1, 0)
	end

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
	print("[SelectSlot] slot:", slot, "valid:", VALID_SLOTS[slot], "inGame:", player:GetAttribute("InGame"))
	if not VALID_SLOTS[slot] then return end
	if not player:GetAttribute("InGame") then return end

	-- Nothing assigned to this slot
	local equippedName = player:GetAttribute("Equipped_" .. slot)
	print("[SelectSlot] equippedName:", equippedName)
	if not equippedName then return end

	local activeSlot = player:GetAttribute("ActiveSlot")
	print("[SelectSlot] activeSlot:", activeSlot, "requested:", slot)

	if activeSlot == slot then
		-- Already holding this slot — do nothing (same key press)
		return
	end

	-- Switch to this slot
	player:SetAttribute("ActiveSlot", slot)
	local tool = findSlotTool(player, slot)
	print("[SelectSlot] findSlotTool result:", tool, tool and tool.Name or "nil")
	equipSlotTool(player, slot)
end)

-- EquipWeapon: loadout UI assigns a weapon/item to a slot
ReplicatedStorage.Remotes.EquipWeapon.OnServerEvent:Connect(function(player, slot, weaponName)
	if not VALID_SLOTS[slot] then return end

	local inGame = player:GetAttribute("InGame")
	local wasActiveSlot = player:GetAttribute("ActiveSlot") == slot

	-- Clear existing tool in that slot (only if in-game, otherwise no tool exists)
	if inGame then
		clearSlotTool(player, slot)
	end

	if weaponName == nil then
		-- Unequip: clear the attribute
		player:SetAttribute("Equipped_" .. slot, nil)
		if wasActiveSlot then
			player:SetAttribute("ActiveSlot", nil)
		end
		return
	end

	-- Validate: weapons must match their registry slot, items must be in VALID_ITEMS
	if slot == "primary" or slot == "secondary" or slot == "melee" then
		if weaponSlotLookup[weaponName] ~= slot then return end
		-- Block equip if weapon is not unlocked
		if not player:GetAttribute("Unlocked_" .. weaponName) then return end
	elseif slot == "item1" or slot == "item2" then
		if not VALID_ITEMS[weaponName] then return end
	end

	-- Always record the loadout selection
	player:SetAttribute("Equipped_" .. slot, weaponName)

	-- Only grant the actual tool when in-game
	if inGame then
		grantTool(player, weaponName, slot)
		if wasActiveSlot then
			equipSlotTool(player, slot)
		end
	end
end)

-- ---------------------------------------------------------------------------
-- PurchaseWeapon: client requests to buy a weapon with gold
-- ---------------------------------------------------------------------------
ReplicatedStorage.Remotes.PurchaseWeapon.OnServerEvent:Connect(function(player, weaponName)
	if not weaponName or type(weaponName) ~= "string" then return end

	-- Already unlocked
	if player:GetAttribute("Unlocked_" .. weaponName) then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Already unlocked!",
		})
		return
	end

	-- Find weapon entry in registry
	local entry = nil
	for _, weapons in WeaponRegistry do
		for _, w in weapons do
			if w.name == weaponName then
				entry = w
				break
			end
		end
		if entry then break end
	end

	if not entry then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Invalid weapon.",
		})
		return
	end

	-- Robux purchases are not handled here (use MarketplaceService in the future)
	if (entry.robuxCost or 0) > 0 then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Robux purchases are not available yet.",
		})
		return
	end

	local cost = entry.unlockCost or 0
	local gold = player:GetAttribute("Gold") or 0

	if gold < cost then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Not enough gold!",
		})
		return
	end

	-- Deduct gold and unlock
	player:SetAttribute("Gold", gold - cost)
	player:SetAttribute("Unlocked_" .. weaponName, true)

	-- TODO: Persist unlock to DataStore here.

	ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
		success = true,
		message = "Purchased!",
		weaponName = weaponName,
	})
end)

-- ---------------------------------------------------------------------------
-- Assign player characters to the PlayerCharacter collision group
-- ---------------------------------------------------------------------------
local function assignPlayerCollisionGroup(character)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "PlayerCharacter"
		end
	end
	-- Catch parts added later (accessories, tools, etc.)
	character.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			desc.CollisionGroup = "PlayerCharacter"
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Apply ZombieBarrier collision group to tagged parts
-- ---------------------------------------------------------------------------
local BARRIER_TAG = "ZombieBarrier"

local function applyBarrierGroup(part)
	if part:IsA("BasePart") then
		part.CollisionGroup = "ZombieBarrier"
	elseif part:IsA("Model") then
		for _, child in part:GetDescendants() do
			if child:IsA("BasePart") then
				child.CollisionGroup = "ZombieBarrier"
			end
		end
	end
end

for _, obj in CollectionService:GetTagged(BARRIER_TAG) do
	applyBarrierGroup(obj)
end
CollectionService:GetInstanceAddedSignal(BARRIER_TAG):Connect(applyBarrierGroup)

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

-- ---------------------------------------------------------------------------
-- XP / Leveling — call grantXP(player, amount) from any server script
-- ---------------------------------------------------------------------------
local reconcilingXP = {} -- re-entrancy guard per player

-- Shared leveling logic: given raw xp and level, resolve level-ups
local function resolveLevel(xp, level)
	while level < LevelConfig.maxLevel do
		local needed = LevelConfig.xpForLevel(level)
		if xp < needed then break end
		xp -= needed
		level += 1
	end
	if level >= LevelConfig.maxLevel then
		level = LevelConfig.maxLevel
		xp = 0
	end
	return xp, level
end

local function applyXPAttributes(player, xp, level)
	reconcilingXP[player] = true
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", xp)
	player:SetAttribute("XPForNextLevel", LevelConfig.xpForLevel(level))
	reconcilingXP[player] = nil
end

local function grantXP(player, amount)
	local level = player:GetAttribute("Level") or LevelConfig.startLevel
	local xp = (player:GetAttribute("XP") or 0) + amount
	xp, level = resolveLevel(xp, level)
	applyXPAttributes(player, xp, level)
end

local function onPlayerAdded(player)
	-- Initialize currency, unlocks, and game state
	player:SetAttribute("Gold", DEFAULT_GOLD)
	player:SetAttribute("InGame", false)
	player:SetAttribute("Level", LevelConfig.startLevel)
	player:SetAttribute("XP", 0)
	player:SetAttribute("XPForNextLevel", LevelConfig.xpForLevel(LevelConfig.startLevel))
	-- WaveLabel/WaveTimer are set by GameStateManager; init empty so HUD doesn't show stale data
	if not player:GetAttribute("WaveLabel") then
		player:SetAttribute("WaveLabel", "")
	end
	if not player:GetAttribute("WaveTimer") then
		player:SetAttribute("WaveTimer", "")
	end
	initPlayerUnlocks(player)

	-- Auto-level when XP is set manually (e.g. from Studio properties panel)
	player.AttributeChanged:Connect(function(attr)
		if attr == "XP" and not reconcilingXP[player] then
			local xp = player:GetAttribute("XP") or 0
			local level = player:GetAttribute("Level") or LevelConfig.startLevel
			local needed = LevelConfig.xpForLevel(level)
			if xp >= needed then
				xp, level = resolveLevel(xp, level)
				applyXPAttributes(player, xp, level)
			end
		end
	end)

	-- Auto-equip starter weapons if nothing equipped yet
	if not player:GetAttribute("Equipped_secondary") then
		player:SetAttribute("Equipped_secondary", "M9")
	end
	if not player:GetAttribute("Equipped_melee") then
		player:SetAttribute("Equipped_melee", "Knife")
	end

	player.CharacterAdded:Connect(function(character)
		assignPlayerCollisionGroup(character)
		startHealthRegen(character)
		-- Defer regrant so GameStateManager's CharacterAdded handler runs first
		-- and clears InGame on death-respawn before we check it here.
		task.defer(function()
			if player:GetAttribute("InGame") then
				regrantEquippedTools(player)
			end
		end)
	end)

	-- Handle already-spawned character (e.g. if PlayerAdded fires late)
	if player.Character then
		assignPlayerCollisionGroup(player.Character)
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
