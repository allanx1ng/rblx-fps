local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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

	if self.isADS then
		spread *= self.config.adsSpreadMultiplier
	end

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

	if self.isADS then
		spread *= self.config.adsSpreadMultiplier
	end

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

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character }

	local result = workspace:Raycast(origin, direction * range, params)
	return result
end

function GunHandler:fire()
	if not self:canFire() then return nil end

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

	local result = self:castRay(spread)
	if result then
		-- Debug: small yellow part at hit position, removed after 2s
		local marker = Instance.new("Part")
		marker.Size = Vector3.new(0.15, 0.15, 0.15)
		marker.Shape = Enum.PartType.Ball
		marker.Material = Enum.Material.Neon
		marker.Color = Color3.fromRGB(255, 200, 0)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CastShadow = false
		marker.Position = result.Position
		marker.Parent = workspace
		game:GetService("Debris"):AddItem(marker, 2)
	end

	return spread
end

function GunHandler:reload()
	if self.isReloading or self.ammo == self.config.capacity then return end
	if self.spareAmmo <= 0 then return end

	self.isReloading = true
	self.isReloadingValue.Value = true

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
	if self.isADS == active then return end
	self.isADS = active
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
	self.spreadValue.Value = 0
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
end

return GunHandler
