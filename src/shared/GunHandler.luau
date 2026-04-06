local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewModelController = require(script.Parent.ViewModelController)

local DEFAULT_FOV = 70
local RAYCAST_DISTANCE = 500  -- studs, fallback if config.range not set


local GunHandler = {}
GunHandler.__index = GunHandler

function GunHandler.new(tool, config)
	local self = setmetatable({}, GunHandler)

	self.tool = tool
	self.config = config

	self.ammo = config.capacity
	self.spareAmmo = config.spareAmmo
	self.isReloading = false
	self.lastFireTime = 0
	self.accumulatedSpread = 0

	self.isADS = false
	self.adsTween = nil
	self.isFiring = false  -- used by auto fire loop
	self.sessionConnections = {} -- disconnected on unequip, rewired on re-equip

	-- NumberValue inside the tool so CrosshairController (different VM) can read spread
	local spreadValue = Instance.new("NumberValue")
	spreadValue.Name = "SpreadValue"
	spreadValue.Value = 0
	spreadValue.Parent = tool
	self.spreadValue = spreadValue

	-- IntValues so GunUIController (different VM) can read ammo counts
	local ammoValue = Instance.new("IntValue")
	ammoValue.Name = "AmmoValue"
	ammoValue.Value = config.capacity
	ammoValue.Parent = tool
	self.ammoValue = ammoValue

	local spareAmmoValue = Instance.new("IntValue")
	spareAmmoValue.Name = "SpareAmmoValue"
	spareAmmoValue.Value = config.spareAmmo
	spareAmmoValue.Parent = tool
	self.spareAmmoValue = spareAmmoValue

	local capacityValue = Instance.new("IntValue")
	capacityValue.Name = "CapacityValue"
	capacityValue.Value = config.capacity
	capacityValue.Parent = tool
	self.capacityValue = capacityValue

	local isReloadingValue = Instance.new("BoolValue")
	isReloadingValue.Name = "IsReloadingValue"
	isReloadingValue.Value = false
	isReloadingValue.Parent = tool
	self.isReloadingValue = isReloadingValue

	-- Static upper bound so external scripts (ammo boxes) know the refill target
	local maxSpareAmmoValue = Instance.new("IntValue")
	maxSpareAmmoValue.Name = "MaxSpareAmmoValue"
	maxSpareAmmoValue.Value = config.spareAmmo
	maxSpareAmmoValue.Parent = tool
	self.maxSpareAmmoValue = maxSpareAmmoValue

	-- Keep self.spareAmmo in sync if an external script writes to SpareAmmoValue
	spareAmmoValue.Changed:Connect(function(newValue)
		self.spareAmmo = newValue
	end)

	return self
end

-- Lerp the ADS spread multiplier based on how far through the ADS transition we are
local function adsSpreadMult(config)
	local progress = ViewModelController.getAdsProgress()
	-- 1.0 at hip → adsSpreadMultiplier at full ADS
	return 1 + (config.adsSpreadMultiplier - 1) * progress
end

-- Read-only spread for display — does NOT decay accumulatedSpread
function GunHandler:peekSpread()
	local dt = tick() - self.lastFireTime
	local decayed = math.max(0, self.accumulatedSpread - dt * self.config.spreadDecayRate)
	local spread = self.config.baseSpread + decayed

	local character = Players.LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MoveDirection.Magnitude > 0 then
			spread += self.config.movementSpread
		end
	end

	spread *= adsSpreadMult(self.config)

	return spread
end

-- Spread for an actual shot — decays accumulatedSpread as a side effect
function GunHandler:getSpread()
	local spread = self.config.baseSpread

	local dt = tick() - self.lastFireTime
	self.accumulatedSpread = math.max(0, self.accumulatedSpread - dt * self.config.spreadDecayRate)

	spread += self.accumulatedSpread

	local character = Players.LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MoveDirection.Magnitude > 0 then
			spread += self.config.movementSpread
		end
	end

	spread *= adsSpreadMult(self.config)

	return spread
end

function GunHandler:canFire()
	return not self.isReloading
		and self.ammo > 0
		and (tick() - self.lastFireTime) >= self.config.fireRate
end

function GunHandler:castRay(spreadDegrees)
	local camera = workspace.CurrentCamera
	local spreadRad = math.rad(spreadDegrees)

	-- Random offset within a cone
	local angle = math.random() * math.pi * 2
	local offset = math.tan(spreadRad) * math.random()
	local direction = (camera.CFrame * CFrame.Angles(
		offset * math.cos(angle),
		offset * math.sin(angle),
		0
	)).LookVector

	local origin = camera.CFrame.Position
	local range = self.config.range or RAYCAST_DISTANCE

	local debugFolder = workspace:FindFirstChild("DebugMarkers")
	if not debugFolder then
		debugFolder = Instance.new("Folder")
		debugFolder.Name = "DebugMarkers"
		debugFolder.Parent = workspace
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character, debugFolder, workspace.CurrentCamera }

	local result = workspace:Raycast(origin, direction * range, params)
	if result and (result.Position - origin).Magnitude < 1 then
		return nil
	end
	return result
end

function GunHandler:fire()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	if self.isReloading then return nil end
	if self.ammo <= 0 then
		ViewModelController.onEmpty()
		return nil
	end
	if (tick() - self.lastFireTime) < self.config.fireRate then return nil end

	local spread = self:getSpread()

	self.ammo -= 1
	self.ammoValue.Value = self.ammo
	if self.ammo == 0 then
		self:reload()
	end
	self.lastFireTime = tick()
	self.accumulatedSpread = math.min(
		self.accumulatedSpread + self.config.rapidFireSpread,
		self.config.maxSpread - self.config.baseSpread
	)

	ViewModelController.onFire()

	-- Notify server so third-person effects (sound, muzzle flash) play for other players
	ReplicatedStorage.Remotes.GunFired:FireServer()

	if self.config.firingMode == "projectile" then
		local camera = workspace.CurrentCamera
		local spreadRad = math.rad(spread)
		local angle = math.random() * math.pi * 2
		local offset = math.tan(spreadRad) * math.random()
		local direction = (camera.CFrame * CFrame.Angles(
			offset * math.cos(angle),
			offset * math.sin(angle),
			0
		)).LookVector
		local cameraOrigin = camera.CFrame.Position

		local speed = self.config.projectileSpeed or 160
		local size  = self.config.projectileSize  or Vector3.new(0.2, 0.2, 3)
		local color = self.config.projectileColor or Color3.fromRGB(0, 255, 255)

		-- ADS: spawn from camera so visual and server projectiles align.
		-- Hip: spawn from muzzle for a natural look.
		local spawnPos = self.isADS and cameraOrigin
			or ViewModelController.getMuzzlePosition() or cameraOrigin

		-- Local-only visual: cosmetic only, never replicates to server.
		-- BodyVelocity added BEFORE parenting to avoid one-frame stationary stutter.
		local localProjectile = Instance.new("Part")
		localProjectile.Size = size
		localProjectile.Color = color
		localProjectile.Material = Enum.Material.Neon
		localProjectile.CanCollide = false
		localProjectile.CastShadow = false
		if self.isADS and cameraOrigin then
			localProjectile.CFrame = CFrame.new(spawnPos, spawnPos + direction)
				* CFrame.new(0, -0.1, -size.Z*2)
		else
			localProjectile.CFrame = CFrame.new(spawnPos, spawnPos + direction)
				* CFrame.new(-0.5, 0.5, -size.Z / 2)
		end

		local bv = Instance.new("BodyVelocity")
		bv.Velocity = direction * speed
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bv.Parent = localProjectile

		if self.config.projectileLight then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Brightness = self.config.projectileLightBrightness or 5
			light.Range = self.config.projectileLightRange or 16
			light.Parent = localProjectile
		end

		localProjectile.Parent = workspace  -- parent last so physics starts with velocity already set
		game:GetService("Debris"):AddItem(localProjectile, (self.config.range or 500) / speed)

		-- Server spawns the authoritative projectile (visible to others, handles damage)
		ReplicatedStorage.Remotes.FireProjectile:FireServer(cameraOrigin, direction, self.config.name)
	else
		local pellets = self.config.pelletsPerShot or 1
		local debugFolder = workspace:FindFirstChild("DebugMarkers")

		for _ = 1, pellets do
			local result = self:castRay(spread)
			if result then
				local hitPart = result.Instance
				-- If we hit a character part, ask the server to apply damage
				if hitPart and hitPart:FindFirstAncestorOfClass("Model") then
					ReplicatedStorage.Remotes.DealDamage:FireServer(hitPart)
				end

				-- Debug marker (parented to DebugMarkers folder so raycasts exclude it)
				local marker = Instance.new("Part")
				marker.Size = Vector3.new(0.15, 0.15, 0.15)
				marker.Shape = Enum.PartType.Ball
				marker.Material = Enum.Material.Neon
				marker.Color = Color3.fromRGB(255, 200, 0)
				marker.Anchored = true
				marker.CanCollide = false
				marker.CastShadow = false
				marker.Position = result.Position
				marker.Parent = debugFolder or workspace
				game:GetService("Debris"):AddItem(marker, 2)
			end
		end
	end

	return spread
end

function GunHandler:reload()
	if self.isReloading or self.ammo == self.config.capacity then return end
	if self.spareAmmo <= 0 then return end

	self.isReloading = true
	self.isReloadingValue.Value = true
	ViewModelController.onReload()

	task.delay(self.config.reloadTime, function()
		local needed = self.config.capacity - self.ammo
		local taken = math.min(needed, self.spareAmmo)
		self.ammo += taken
		self.spareAmmo -= taken
		self.isReloading = false
		self.isReloadingValue.Value = false
		self.ammoValue.Value = self.ammo
		self.spareAmmoValue.Value = self.spareAmmo
	end)
end

function GunHandler:setADS(active)
	if active then
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
	end
	if self.isADS == active then return end
	self.isADS = active
	Players.LocalPlayer:SetAttribute("IsADS", active)
	ViewModelController.setADS(active)
	local camera = workspace.CurrentCamera
	local targetFOV = active
		and (DEFAULT_FOV / self.config.adsMagnification)
		or DEFAULT_FOV

	if self.adsTween then
		self.adsTween:Cancel()
	end

	self.adsTween = TweenService:Create(
		camera,
		TweenInfo.new(self.config.adsSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = targetFOV }
	)
	self.adsTween:Play()
end

-- Wired on equip, torn down on unequip so they reconnect cleanly each time
function GunHandler:startSession()
	ViewModelController.show(self.config)

	table.insert(self.sessionConnections, RunService.RenderStepped:Connect(function()
		self.spreadValue.Value = self:peekSpread()
		-- Store FOV ratio so SensitivityController can apply it alongside the user setting
		Players.LocalPlayer:SetAttribute("FOVSensScale", workspace.CurrentCamera.FieldOfView / DEFAULT_FOV)
	end))

	table.insert(self.sessionConnections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.R then
			self:reload()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:setADS(true)
		end
	end))

	table.insert(self.sessionConnections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:setADS(false)
		end
	end))

	if self.config.autoFire then
		print("[GunHandler] Auto fire wired for", self.config.name)
		-- Mouse1 must NOT check gameProcessed — Tool equip marks it as processed
		table.insert(self.sessionConnections, UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				print("[GunHandler] Mouse1 down — starting fire loop")
				self.isFiring = true
				task.spawn(function()
					while self.isFiring do
						local spread = self:fire()
						print("[GunHandler] fired, spread:", spread, "ammo:", self.ammo)
						task.wait(self.config.fireRate)
					end
				end)
			end
		end))

		table.insert(self.sessionConnections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				print("[GunHandler] Mouse1 up — stopping fire loop")
				self.isFiring = false
			end
		end))
	end
end

function GunHandler:endSession()
	for _, conn in self.sessionConnections do
		conn:Disconnect()
	end
	self.sessionConnections = {}

	if self.isADS then
		self:setADS(false)
	end

	self.isFiring = false
	if self.spreadValue.Parent then
		self.spreadValue.Value = 0
	end
	Players.LocalPlayer:SetAttribute("FOVSensScale", 1)
	ViewModelController.hide()
end

-- Called once when the tool enters the Backpack — wires permanent events only
function GunHandler:init()
	self.tool.Equipped:Connect(function()
		self:startSession()
	end)

	self.tool.Unequipped:Connect(function()
		self:endSession()
	end)

	-- Auto fire is handled in startSession via InputBegan; semi-auto uses Activated
	if not self.config.autoFire then
		self.tool.Activated:Connect(function()
			self:fire()
		end)
	end

	-- CharacterRemoving guarantees endSession() is always called on death so that
	-- session connections (RenderStepped, InputBegan, etc.) don't outlive the session.
	-- Do NOT self-disconnect: it must fire on every death, not just the first.
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		self:endSession()
	end)
end

return GunHandler
