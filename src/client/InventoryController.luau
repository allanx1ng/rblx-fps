-- Handles keybind-based slot selection (1-5) and fires SelectSlot to the server.
-- Replaces the default Roblox backpack system.
--
-- Key mapping:
--   1 = primary
--   2 = secondary
--   4 = item1
--   5 = item2

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelectSlot = ReplicatedStorage.Remotes.SelectSlot

local KEY_TO_SLOT = {
	[Enum.KeyCode.One]  = "primary",
	[Enum.KeyCode.Two]  = "secondary",
	[Enum.KeyCode.Four] = "item1",
	[Enum.KeyCode.Five] = "item2",
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local slot = KEY_TO_SLOT[input.KeyCode]
	if slot then
		SelectSlot:FireServer(slot)
	end
end)

return true
