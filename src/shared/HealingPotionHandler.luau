local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ViewModelController = require(script.Parent.ViewModelController)

local HealingPotionHandler = {}
HealingPotionHandler.__index = HealingPotionHandler

function HealingPotionHandler.new(tool, config)
	local self = setmetatable({}, HealingPotionHandler)

	self.tool = tool
	self.config = config
	self.lastUseTime = 0
	self.sessionConnections = {}

	-- BoolValue so UI scripts can read cooldown state
	local cooldownValue = Instance.new("BoolValue")
	cooldownValue.Name = "OnCooldown"
	cooldownValue.Value = false
	cooldownValue.Parent = tool
	self.cooldownValue = cooldownValue

	return self
end

function HealingPotionHandler:canUse()
	if (tick() - self.lastUseTime) < self.config.cooldown then return false end

	local character = Players.LocalPlayer.Character
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	-- Don't use if already at full health
	if humanoid.Health >= humanoid.MaxHealth then return false end

	return true
end

function HealingPotionHandler:use()
	if not self:canUse() then return end

	self.lastUseTime = tick()
	self.cooldownValue.Value = true

	-- Play drink sound if the viewmodel has one
	local activeModel = workspace.CurrentCamera:FindFirstChild(self.config.viewModelName)
	if activeModel then
		local drinkSound = activeModel:FindFirstChild("DrinkSound")
		if drinkSound then drinkSound:Play() end
	end

	-- Ask the server to actually heal us
	ReplicatedStorage.Remotes.UseHealingPotion:FireServer(self.config.name)

	-- Start cooldown timer
	task.delay(self.config.cooldown, function()
		self.cooldownValue.Value = false
	end)
end

function HealingPotionHandler:startSession()
	-- Show the healing potion viewmodel
	ViewModelController.show({
		isGun = false,
		viewModelName = self.config.viewModelName,
		hipOffset = self.config.hipOffset,
		adsDistance = self.config.adsDistance or 0,
		adsSpeed = self.config.adsSpeed or 0.2,
		equipTime = self.config.equipTime,
		equipOffset = self.config.equipOffset,
		recoilKick = 0,
		recoilRotation = 0,
		recoilRecovery = 10,
	})
end

function HealingPotionHandler:endSession()
	for _, conn in self.sessionConnections do
		conn:Disconnect()
	end
	self.sessionConnections = {}
	ViewModelController.hide()
end

function HealingPotionHandler:init()
	self.tool.Equipped:Connect(function()
		self:startSession()
	end)

	self.tool.Unequipped:Connect(function()
		self:endSession()
	end)

	-- Use potion on click
	self.tool.Activated:Connect(function()
		self:use()
	end)

	Players.LocalPlayer.CharacterRemoving:Connect(function()
		self:endSession()
	end)
end

return HealingPotionHandler
