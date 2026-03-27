-- Animates the Crosshair ScreenGui based on the equipped gun's SpreadValue.
--
-- GunHandler (tool VM) writes spread to a NumberValue inside the Tool.
-- This script (StarterPlayerScripts VM) reads it — the only way to share
-- data across separate LocalScript VMs is through actual Roblox instances.
--
-- Expected Crosshair structure in StarterGui:
--   Crosshair (ScreenGui)
--     Top / Bottom / Left / Right  (Frames)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PIXELS_PER_DEGREE = 5

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Mutable GUI references — refreshed on every respawn
local crosshairGui
local arms = {}
local basePos = {}

local function fetchGui()
	crosshairGui = playerGui:WaitForChild("Crosshair")
	arms.top    = crosshairGui:WaitForChild("Top")
	arms.bottom = crosshairGui:WaitForChild("Bottom")
	arms.left   = crosshairGui:WaitForChild("Left")
	arms.right  = crosshairGui:WaitForChild("Right")
	basePos.top    = arms.top.Position
	basePos.bottom = arms.bottom.Position
	basePos.left   = arms.left.Position
	basePos.right  = arms.right.Position
end

fetchGui()

local function setArmPositions(extraOffset)
	arms.top.Position    = basePos.top    + UDim2.new(0, 0,           0, -extraOffset)
	arms.bottom.Position = basePos.bottom + UDim2.new(0, 0,           0,  extraOffset)
	arms.left.Position   = basePos.left   + UDim2.new(0, -extraOffset, 0, 0)
	arms.right.Position  = basePos.right  + UDim2.new(0,  extraOffset, 0, 0)
end

local function getSpread()
	local character = player.Character
	if not character then return 0 end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return 0 end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then return 0 end

	local spreadValue = tool:FindFirstChild("SpreadValue")
	if not spreadValue then return 0 end

	return spreadValue.Value
end

-- Re-fetch GUI references after every respawn (ScreenGuis with ResetOnSpawn=true
-- are destroyed and recreated, so stale references stop working).
player.CharacterAdded:Connect(function()
	fetchGui()
end)

RunService.RenderStepped:Connect(function()
	local extraOffset = 2 * getSpread() * PIXELS_PER_DEGREE
	setArmPositions(extraOffset)
end)

return {}
