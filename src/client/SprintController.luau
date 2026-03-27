-- Handles sprinting, stamina drain/regen, and walk speed.
--
-- Stats are stored as player Attributes, initialized from PlayerStats defaults.
-- Any system (server, other scripts) can call player:SetAttribute() to change
-- a stat and this script will reflect it instantly via AttributeChanged.
--
-- Expected SprintStamina ScreenGui structure in StarterGui:
--   SprintStamina (ScreenGui)
--     Container (Frame)
--       Fill (Frame)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Initialize attributes from PlayerStats defaults only if not already set.
-- A server script setting them first will take precedence.
local function initAttr(name, default)
	if player:GetAttribute(name) == nil then
		player:SetAttribute(name, default)
	end
end

initAttr("WalkSpeed",          PlayerStats.walkSpeed)
initAttr("SprintSpeed",        PlayerStats.sprintSpeed)
initAttr("MaxStamina",         PlayerStats.maxStamina)
initAttr("StaminaDrainRate",   PlayerStats.staminaDrainRate)
initAttr("StaminaRegenRate",   PlayerStats.staminaRegenRate)
initAttr("StaminaRegenDelay",  PlayerStats.staminaRegenDelay)

-- Always read live attribute values so stat changes apply immediately
local function walkSpeed()        return player:GetAttribute("WalkSpeed") end
local function sprintSpeed()      return player:GetAttribute("SprintSpeed") end
local function maxStamina()       return player:GetAttribute("MaxStamina") end
local function staminaDrainRate() return player:GetAttribute("StaminaDrainRate") end
local function staminaRegenRate() return player:GetAttribute("StaminaRegenRate") end
local function staminaRegenDelay() return player:GetAttribute("StaminaRegenDelay") end

local stamina = maxStamina()
local isSprinting = false
local timeSinceRelease = 0

-- Mutable GUI references — refreshed on every respawn
local gui
local container
local fill

local function fetchGui()
	gui = playerGui:WaitForChild("SprintStamina")
	container = gui:WaitForChild("Container")
	fill = container:WaitForChild("Fill")
end

fetchGui()

local function setSprinting(value)
	isSprinting = value
	if not value then
		timeSinceRelease = 0
	end
end

-- Sprint is suppressed while crouching or ADS, or when W isn't held
local function canSprint()
	return isSprinting
		and not player:GetAttribute("IsCrouching")
		and not player:GetAttribute("IsADS")
		and UserInputService:IsKeyDown(Enum.KeyCode.W)
end

local function updateSpeed()
	if player:GetAttribute("IsCrouching") then return end  -- CrouchController owns speed while crouching
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local speed = if canSprint() and stamina > 0 then sprintSpeed() else walkSpeed()
		if player:GetAttribute("IsADS") then
			speed *= 0.5
		end
		humanoid.WalkSpeed = speed
	end
end

-- If MaxStamina drops below current stamina, clamp immediately.
player.AttributeChanged:Connect(function(attr)
	if attr == "MaxStamina" then
		stamina = math.min(stamina, maxStamina())
	end
end)

-- Re-fetch GUI references and reset state after every respawn.
player.CharacterAdded:Connect(function()
	setSprinting(false)
	stamina = maxStamina()
	fetchGui()
end)

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local isAlive = humanoid ~= nil and humanoid.Health > 0

	local max = maxStamina()

	local isMoving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0
	if isAlive and canSprint() and isMoving and stamina > 0 then
		stamina = math.max(0, stamina - staminaDrainRate() * dt)
	elseif not (canSprint() and isMoving) or not isAlive then
		timeSinceRelease += dt
		if timeSinceRelease >= staminaRegenDelay() then
			stamina = math.min(max, stamina + staminaRegenRate() * dt)
		end
	end

	if isAlive then
		updateSpeed()
	end

	fill.Size = UDim2.new(stamina / max, 0, 1, 0)
	gui.Enabled = isAlive and stamina < max
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprinting(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprinting(false)
	end
end)

return {}
