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

	-- NumberValue so GunUIController can display a countdown
	local cooldownEndTime = Instance.new("NumberValue")
	cooldownEndTime.Name = "CooldownEndTime"
	cooldownEndTime.Value = 0
	cooldownEndTime.Parent = tool
	self.cooldownEndTime = cooldownEndTime

	return self
end

function HealingPotionHandler:canUse()
	if (tick() - self.lastUseTime) < self.config.cooldown then return false end

	-- Check uses remaining
	local usesValue = self.tool:FindFirstChild("UsesValue")
	if usesValue and usesValue.Value <= 0 then return false end

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
	self.cooldownEndTime.Value = tick() + self.config.cooldown

	-- Play use animation on viewmodel
	ViewModelController.onUse(self.config)

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

function HealingPotionHandler:showViewModel()
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

function HealingPotionHandler:startSession()
	local usesValue = self.tool:FindFirstChild("UsesValue")

	-- Don't show viewmodel if already out of uses
	if usesValue and usesValue.Value <= 0 then
		-- Still watch for restock so viewmodel reappears
		table.insert(self.sessionConnections, usesValue.Changed:Connect(function()
			if usesValue.Value > 0 then
				self:showViewModel()
			end
		end))
		return
	end

	self:showViewModel()

	-- Hide viewmodel when uses run out, re-show on restock
	if usesValue then
		table.insert(self.sessionConnections, usesValue.Changed:Connect(function()
			if usesValue.Value <= 0 then
				ViewModelController.hide()
			else
				-- Restocked — re-show if tool is still equipped
				if self.tool.Parent == Players.LocalPlayer.Character then
					self:showViewModel()
				end
			end
		end))
	end
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
