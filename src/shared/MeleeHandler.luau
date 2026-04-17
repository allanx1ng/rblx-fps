local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewModelController = require(script.Parent.ViewModelController)

local MeleeHandler = {}
MeleeHandler.__index = MeleeHandler

function MeleeHandler.new(tool, config)
	local self = setmetatable({}, MeleeHandler)

	self.tool = tool
	self.config = config

	self.lastSwingTime = 0
	self.sessionConnections = {}
	self.hiddenParts = {} -- parts we made invisible on the local player's tool

	return self
end

-- Hide the tool's Handle (and any other visible parts) for the local player
-- so it doesn't show in first person. Other players still see it normally.
local function hideToolParts(tool, hiddenParts)
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(hiddenParts, { part = part, originalTransparency = part.LocalTransparencyModifier })
			part.LocalTransparencyModifier = 1
		end
	end
end

local function restoreToolParts(hiddenParts)
	for _, entry in hiddenParts do
		if entry.part and entry.part.Parent then
			entry.part.LocalTransparencyModifier = entry.originalTransparency
		end
	end
	table.clear(hiddenParts)
end

function MeleeHandler:canSwing()
	return (tick() - self.lastSwingTime) >= self.config.swingCooldown
end

function MeleeHandler:swing()
	if Players.LocalPlayer:GetAttribute("InGameSettingsOpen") then return end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	if not self:canSwing() then return end

	self.lastSwingTime = tick()

	-- Trigger first-person swing animation on the view model
	ViewModelController.onSwing(self.config)

	-- Notify server for third-person slash animation (replicates to all clients)
	ReplicatedStorage.Remotes.MeleeSwing:FireServer()

	-- Hit detection after the wind-up portion of the animation
	task.delay(self.config.hitDelay, function()
		self:detectHit()
	end)
end

function MeleeHandler:detectHit()
	local character = Players.LocalPlayer.Character
	if not character then return end

	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * self.config.range

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace.CurrentCamera }

	local result = workspace:Raycast(origin, direction, params)
	if result and result.Instance then
		local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
		if hitModel then
			local hitHumanoid = hitModel:FindFirstChildOfClass("Humanoid")
			if hitHumanoid and hitHumanoid.Health > 0 then
				ReplicatedStorage.Remotes.MeleeDamage:FireServer(result.Instance, result.Position)
			end
		end
	end
end

function MeleeHandler:startSession()
	ViewModelController.show(self.config)

	-- Hide the physical tool so it doesn't render in first person
	hideToolParts(self.tool, self.hiddenParts)

	-- Keep parts hidden if new descendants are added (e.g. accessories)
	table.insert(self.sessionConnections, self.tool.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			table.insert(self.hiddenParts, { part = desc, originalTransparency = desc.LocalTransparencyModifier })
			desc.LocalTransparencyModifier = 1
		end
	end))

	-- LocalTransparencyModifier resets every render frame, so re-apply it
	table.insert(self.sessionConnections, RunService.RenderStepped:Connect(function()
		for _, entry in self.hiddenParts do
			if entry.part and entry.part.Parent then
				entry.part.LocalTransparencyModifier = 1
			end
		end
	end))
end

function MeleeHandler:endSession()
	for _, conn in self.sessionConnections do
		conn:Disconnect()
	end
	self.sessionConnections = {}

	restoreToolParts(self.hiddenParts)
	ViewModelController.hide()
end

function MeleeHandler:init()
	self.tool.Equipped:Connect(function()
		self:startSession()
	end)

	self.tool.Unequipped:Connect(function()
		self:endSession()
	end)

	-- Use Tool.Activated for swing — fires on click.
	-- Third-person slash animation is handled server-side via MeleeSwing remote.
	self.tool.Activated:Connect(function()
		self:swing()
	end)

	Players.LocalPlayer.CharacterRemoving:Connect(function()
		self:endSession()
	end)
end

return MeleeHandler
