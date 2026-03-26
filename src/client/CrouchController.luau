-- Hold LeftCtrl / RightCtrl to crouch.
-- Sets WalkSpeed to CrouchSpeed and sets the IsCrouching attribute
-- so SprintController (and future scripts) can react without polling.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local function crouchSpeed()
	return player:GetAttribute("CrouchSpeed") or 8
end

local function walkSpeed()
	return player:GetAttribute("WalkSpeed") or 16
end

local function setCrouch(active)
	player:SetAttribute("IsCrouching", active)

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.WalkSpeed = active and crouchSpeed() or walkSpeed()
end

player.CharacterAdded:Connect(function()
	player:SetAttribute("IsCrouching", false)
end)

player:SetAttribute("IsCrouching", false)
player:SetAttribute("CrouchSpeed", player:GetAttribute("CrouchSpeed") or 8)

-- Hold to crouch
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftControl
		or input.KeyCode == Enum.KeyCode.RightControl then
		setCrouch(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftControl
		or input.KeyCode == Enum.KeyCode.RightControl then
		setCrouch(false)
	end
end)

-- Toggle (uncomment below and comment out hold above to swap back for testing)
-- UserInputService.InputBegan:Connect(function(input, gameProcessed)
-- 	if gameProcessed then return end
-- 	if input.KeyCode == Enum.KeyCode.LeftControl
-- 		or input.KeyCode == Enum.KeyCode.RightControl then
-- 		setCrouch(not isCrouching)
-- 	end
-- end)

return {}
