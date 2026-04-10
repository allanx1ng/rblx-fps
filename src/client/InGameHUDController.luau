-- Manages the InGameHUD ScreenGui — shows when InGame=true, hides when false.
--
-- Expected structure in StarterGui > InGameHUD (ScreenGui):
--
-- HUD data labels (all optional, searched with FindFirstChild recursively):
--   GoldLabel    (TextLabel)
--   LevelLabel   (TextLabel)
--   XPBar        (Frame) containing Fill (Frame, width scaled 0-1)
--   XPLabel      (TextLabel)
--   WaveStatus   (TextLabel)
--
-- Health bar (optional):
--   HealthBar    (Frame) containing:
--     Fill       (Frame, width scaled 0-1, color lerps green→red)
--     HealthText (TextLabel, shows "85 / 100")
--
-- Settings (optional):
--   Button tagged "InGameSettingsButton" — toggles the panel
--   InGameSettingsPanel (Frame) — tag its slider/toggle children with the same
--     tags as lobby (SettingMasterVolume, etc.) so SettingsController auto-wires them.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ---------------------------------------------------------------------------
-- Resolve GUI references
-- ---------------------------------------------------------------------------
local inGameHUD = playerGui:WaitForChild("InGameHUD")
inGameHUD.ResetOnSpawn = false
inGameHUD.Enabled = false

local goldLabel   = inGameHUD:FindFirstChild("GoldLabel", true)
local levelLabel  = inGameHUD:FindFirstChild("LevelLabel", true)
local xpBar       = inGameHUD:FindFirstChild("XPBar", true)
local xpFill      = xpBar and xpBar:FindFirstChild("Fill")
local xpLabel     = inGameHUD:FindFirstChild("XPLabel", true)
local waveStatus  = inGameHUD:FindFirstChild("WaveStatus", true)

local healthBar   = inGameHUD:FindFirstChild("HealthBar", true)
local healthFill  = healthBar and healthBar:FindFirstChild("Fill")
local healthText  = healthBar and healthBar:FindFirstChild("HealthText")

local settingsPanel = inGameHUD:FindFirstChild("InGameSettingsPanel", true)

local HEALTH_GREEN = Color3.fromRGB(50, 200, 50)
local HEALTH_RED   = Color3.fromRGB(200, 50, 50)

-- ---------------------------------------------------------------------------
-- Settings panel toggle
-- ---------------------------------------------------------------------------
local settingsOpen = false

local function closeSettingsPanel()
	if settingsPanel then
		settingsOpen = false
		settingsPanel.Visible = false
	end
end

local function toggleSettings()
	if not settingsPanel then return end
	settingsOpen = not settingsOpen
	settingsPanel.Visible = settingsOpen
end

-- Wire up any button tagged "InGameSettingsButton"
for _, btn in CollectionService:GetTagged("InGameSettingsButton") do
	if btn:IsA("GuiButton") then
		btn.Activated:Connect(toggleSettings)
	end
end
CollectionService:GetInstanceAddedSignal("InGameSettingsButton"):Connect(function(btn)
	if btn:IsA("GuiButton") then
		btn.Activated:Connect(toggleSettings)
	end
end)

-- ESC closes settings in-game
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape and settingsOpen then
		closeSettingsPanel()
	end
end)

-- ---------------------------------------------------------------------------
-- Data helpers
-- ---------------------------------------------------------------------------
local function formatNumber(n)
	local formatted = tostring(math.floor(n))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

local function updateGold()
	if not goldLabel then return end
	goldLabel.Text = formatNumber(player:GetAttribute("Gold") or 0)
end

local function updateXP()
	local xp = player:GetAttribute("XP") or 0
	local level = player:GetAttribute("Level") or 1
	local xpForNext = player:GetAttribute("XPForNextLevel") or 1000

	if levelLabel then levelLabel.Text = "Lv. " .. level end
	if xpLabel then xpLabel.Text = formatNumber(xp) .. " / " .. formatNumber(xpForNext) .. " XP" end
	if xpFill then xpFill.Size = UDim2.new(math.clamp(xp / xpForNext, 0, 1), 0, 1, 0) end
end

local function updateWaveStatus()
	if not waveStatus then return end
	waveStatus.Text = player:GetAttribute("WaveStatus") or ""
end

-- ---------------------------------------------------------------------------
-- Health bar
-- ---------------------------------------------------------------------------
local healthConn = nil

local function updateHealth(humanoid)
	if not healthBar then return end
	local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	if healthFill then
		healthFill.Size = UDim2.new(ratio, 0, 1, 0)
		healthFill.BackgroundColor3 = HEALTH_GREEN:Lerp(HEALTH_RED, 1 - ratio)
	end
	if healthText then
		healthText.Text = math.ceil(humanoid.Health) .. " / " .. math.ceil(humanoid.MaxHealth)
	end
end

local function watchHealth(character)
	if healthConn then healthConn:Disconnect() end
	if not healthBar then return end

	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	updateHealth(humanoid)
	healthConn = humanoid.HealthChanged:Connect(function()
		updateHealth(humanoid)
	end)
end

-- ---------------------------------------------------------------------------
-- Lifecycle — react to InGame attribute
-- ---------------------------------------------------------------------------
local function onInGameChanged()
	local inGame = player:GetAttribute("InGame") == true
	inGameHUD.Enabled = inGame

	if inGame then
		closeSettingsPanel()
		updateGold()
		updateXP()
		updateWaveStatus()
		if player.Character then
			watchHealth(player.Character)
		end
	else
		if healthConn then
			healthConn:Disconnect()
			healthConn = nil
		end
	end
end

player.AttributeChanged:Connect(function(attr)
	if attr == "InGame" then
		onInGameChanged()
	elseif attr == "Gold" then
		updateGold()
	elseif attr == "XP" or attr == "Level" or attr == "XPForNextLevel" then
		updateXP()
	elseif attr == "WaveStatus" then
		updateWaveStatus()
	end
end)

player.CharacterAdded:Connect(function(character)
	if player:GetAttribute("InGame") then
		watchHealth(character)
	end
end)

-- Initial state
onInGameChanged()

return {}
