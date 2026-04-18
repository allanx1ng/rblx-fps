-- Client-side handler for the SpeedPill active item.
-- Mirrors the HealingPotionHandler pattern: equip/unequip viewmodel, use on click.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewModelController = require(script.Parent.ViewModelController)

local SpeedPillHandler = {}
SpeedPillHandler.__index = SpeedPillHandler

function SpeedPillHandler.new(tool, config)
	local self = setmetatable({}, SpeedPillHandler)
	self.tool = tool
	self.config = config
	self.lastUseTime = 0
	self.sessionConnections = {}

	local cooldownValue = Instance.new("BoolValue")
	cooldownValue.Name = "OnCooldown"
	cooldownValue.Value = false
	cooldownValue.Parent = tool
	self.cooldownValue = cooldownValue

	local cooldownEndTime = Instance.new("NumberValue")
	cooldownEndTime.Name = "CooldownEndTime"
	cooldownEndTime.Value = 0
	cooldownEndTime.Parent = tool
	self.cooldownEndTime = cooldownEndTime

	return self
end

function SpeedPillHandler:canUse()
	if (tick() - self.lastUseTime) < self.config.cooldown then return false end

	-- Check uses remaining
	local usesValue = self.tool:FindFirstChild("UsesValue")
	if usesValue and usesValue.Value <= 0 then return false end

	local player = Players.LocalPlayer
	if player:GetAttribute("SpeedPillActive") then return false end

	local character = player.Character
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	return true
end

function SpeedPillHandler:use()
	if not self:canUse() then return end

	self.lastUseTime = tick()
	self.cooldownValue.Value = true
	self.cooldownEndTime.Value = tick() + self.config.cooldown

	-- Play use animation on viewmodel
	ViewModelController.onUse(self.config)

	local activeModel = workspace.CurrentCamera:FindFirstChild(self.config.viewModelName)
	if activeModel then
		local drinkSound = activeModel:FindFirstChild("DrinkSound")
		if drinkSound then drinkSound:Play() end
	end

	ReplicatedStorage.Remotes.UseSpeedPill:FireServer()

	task.delay(self.config.cooldown, function()
		self.cooldownValue.Value = false
	end)
end

function SpeedPillHandler:showViewModel()
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

function SpeedPillHandler:startSession()
	local usesValue = self.tool:FindFirstChild("UsesValue")

	-- Don't show viewmodel if already out of uses
	if usesValue and usesValue.Value <= 0 then
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
				if self.tool.Parent == Players.LocalPlayer.Character then
					self:showViewModel()
				end
			end
		end))
	end
end

function SpeedPillHandler:endSession()
	for _, conn in self.sessionConnections do
		conn:Disconnect()
	end
	self.sessionConnections = {}
	ViewModelController.hide()
end

function SpeedPillHandler:init()
	self.tool.Equipped:Connect(function()
		self:startSession()
	end)

	self.tool.Unequipped:Connect(function()
		self:endSession()
	end)

	self.tool.Activated:Connect(function()
		self:use()
	end)

	Players.LocalPlayer.CharacterRemoving:Connect(function()
		self:endSession()
	end)
end

return SpeedPillHandler
