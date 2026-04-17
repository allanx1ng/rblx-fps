-- FireProjectile remote handler — server spawns and damages with projectiles.
-- Supports two firingModes:
--   "projectile"           — straight-line hit, optional pierce falloff
--   "explosive_projectile" — detonates on impact with tiered blast damage

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local DamageUtil = require(script.Parent:WaitForChild("DamageUtil"))
local Guns = ReplicatedStorage.Shared.Guns

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
	-- Explosive projectile mesh faces +X when at (0,0,0); rotate -90° on Y to align with -Z (forward).
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

			-- Roblox Explosion doesn't reliably play audio — anchor a sound part at the blast point.
			local explosionSound = Instance.new("Sound")
			explosionSound.SoundId = "rbxasset://sounds/collide.ogg"
			explosionSound.Volume = 1.5
			explosionSound.RollOffMaxDistance = 200
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
				if Players:GetPlayerFromCharacter(victimChar) then return end

				local dmg = 0
				for _, tier in config.blastTiers do
					if distance <= tier.radius then
						dmg = tier.damage
						break
					end
				end
				if dmg <= 0 then return end

				damaged[humanoid] = true
				victimChar:SetAttribute("_LastDamagerUserId", shooter.UserId)
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
				if Players:GetPlayerFromCharacter(victimCharacter) then return end

				-- Pierce damage falloff: linearly decreases from 1.0 to 1/(maxPierceCount+1)
				local totalHits = maxPierceCount + 1
				local damageMult = (totalHits - pierced) / totalHits
				damagedHumanoids[humanoid] = true
				victimCharacter:SetAttribute("_LastDamagerUserId", shooter.UserId)
				humanoid:TakeDamage(config.damage * DamageUtil.getMultiplier(otherPart.Name, config) * damageMult)

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
