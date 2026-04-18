-- Shared tool granting/stripping helpers.
-- Both Loadout and GameStateManager require this module so the melee-handle
-- cloning logic lives in exactly one place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Melee = ReplicatedStorage.Shared:WaitForChild("Melee")
local ActiveItems = ReplicatedStorage.Shared:WaitForChild("Items"):WaitForChild("Actives")
local ThirdPersonWeapons = ReplicatedStorage:WaitForChild("ThirdPersonWeapons")
local WeaponTools = ServerStorage:WaitForChild("WeaponTools")

-- Slots that correspond to actual Tool instances (excludes buff slots).
local TOOL_SLOTS = { "primary", "secondary", "melee", "item1", "item2" }

local ToolManager = {}

function ToolManager.findSlotTool(player, slot)
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

function ToolManager.clearSlotTool(player, slot)
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

function ToolManager.stripAllTools(player)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then child:Destroy() end
		end
	end
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then child:Destroy() end
		end
	end
end

function ToolManager.grantTool(player, toolName, slot)
	local template = WeaponTools:FindFirstChild(toolName)
	if not template then return end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local tool = template:Clone()
	tool:SetAttribute("Slot", slot)

	if Melee:FindFirstChild(toolName) then
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
		tool.Grip = CFrame.new(0, 0, -1.7, 0, 0, 1, 1, 0, 0, 0, 1, 0)
	end

	-- Third-person handle for item tools (clone from ThirdPersonWeapons if available)
	if string.find(slot, "^item") and not tool:FindFirstChild("Handle") then
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

	-- Add uses tracking for consumable item tools
	if string.find(slot, "^item") then
		local configModule = ActiveItems:FindFirstChild(toolName)
		if configModule then
			local config = require(configModule)
			local maxUses = config.maxUses or 2
			local usesValue = Instance.new("IntValue")
			usesValue.Name = "UsesValue"
			usesValue.Value = maxUses
			usesValue.Parent = tool
			local maxUsesValue = Instance.new("IntValue")
			maxUsesValue.Name = "MaxUsesValue"
			maxUsesValue.Value = maxUses
			maxUsesValue.Parent = tool
		end
	end

	tool.Parent = backpack
end

function ToolManager.equipSlotTool(player, slot)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local tool = ToolManager.findSlotTool(player, slot)
	if not tool then return end
	if tool.Parent == character then return end

	humanoid:UnequipTools()
	humanoid:EquipTool(tool)
end

function ToolManager.grantEquippedTools(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	for _, slot in TOOL_SLOTS do
		local toolName = player:GetAttribute("Equipped_" .. slot)
		if toolName then
			ToolManager.grantTool(player, toolName, slot)
		end
	end
end

return ToolManager
