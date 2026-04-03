-- Watches for equipped tools being removed from the character (e.g. server-side
-- Destroy during weapon swap). When the currently held tool vanishes without
-- Unequipped firing, this controller forces ViewModelController.hide() so the
-- first-person model doesn't stay orphaned in the world.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewModelController = require(ReplicatedStorage.Shared.ViewModelController)

local player = Players.LocalPlayer

local function watchCharacter(character)
	-- Track which tool is currently equipped (parented to character)
	local function getEquippedTool()
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				return child
			end
		end
		return nil
	end

	character.ChildRemoved:Connect(function(child)
		if not child:IsA("Tool") then return end

		-- If no tool remains in the character, the held weapon was removed.
		-- The normal Unequipped -> endSession -> hide path may not have fired,
		-- so force viewmodel cleanup as a safety net.
		if not getEquippedTool() then
			ViewModelController.hide()
		end
	end)
end

if player.Character then
	watchCharacter(player.Character)
end

player.CharacterAdded:Connect(watchCharacter)

return true
