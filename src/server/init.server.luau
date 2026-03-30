local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
-- local DataStoreService = game:GetService("DataStoreService")
-- local MarketplaceService = game:GetService("MarketplaceService")

local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)
local Guns = ReplicatedStorage.Shared.Guns

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
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		startHealthRegen(character)
	end)

	-- Handle already-spawned character (e.g. if PlayerAdded fires late)
	if player.Character then
		startHealthRegen(player.Character)
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
