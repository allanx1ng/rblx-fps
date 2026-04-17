-- Manages the InGameHUD ScreenGui — shows when InGame=true, hides when false.
--
-- Lives at: StarterGui > InGameHUD > InGameHUDController (LocalScript)
--
-- Gold/XP/Level/Wave display has moved to PersistentHUD.
--
-- Expected children (all optional):
--   HealthBar (Frame):
--     Fill       (Frame, width scaled 0-1, color lerps green→red)
--     HealthText (TextLabel, shows "85 / 100")
--
--   InGameSettingsPanel (Frame) — settings panel, toggled by button
--   Button tagged "InGameSettingsButton" — toggles the panel
--   Tag settings children with SettingMasterVolume, SettingMouseSensitivity,
--     SettingFPSCounter so SettingsController auto-wires them.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local inGameHUD = script.Parent
inGameHUD.Enabled = false

-- ---------------------------------------------------------------------------
-- Health bar
-- ---------------------------------------------------------------------------
local healthBar  = inGameHUD:FindFirstChild("HealthBar", true)
local healthFill = healthBar and healthBar:FindFirstChild("Fill")
local healthText = healthBar and healthBar:FindFirstChild("HealthText")

local HEALTH_GREEN = Color3.fromRGB(50, 200, 50)
local HEALTH_RED   = Color3.fromRGB(200, 50, 50)

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
-- Settings panel toggle
-- ---------------------------------------------------------------------------
local settingsPanel = inGameHUD:FindFirstChild("InGameSettingsPanel", true)
local settingsOpen = false

-- Override MouseBehavior every frame while settings are open, because
-- LockFirstPerson resets it to LockCenter each render step.
local mouseOverrideConn = nil

local function startMouseOverride()
	if mouseOverrideConn then return end
	mouseOverrideConn = RunService.RenderStepped:Connect(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
end

local function stopMouseOverride()
	if mouseOverrideConn then
		mouseOverrideConn:Disconnect()
		mouseOverrideConn = nil
	end
end

local function closeSettingsPanel()
	if settingsPanel then
		settingsOpen = false
		settingsPanel.Visible = false
		player:SetAttribute("InGameSettingsOpen", false)
		stopMouseOverride()
		UserInputService.MouseIconEnabled = false
	end
end

local function toggleSettings()
	if not settingsPanel then return end
	settingsOpen = not settingsOpen
	settingsPanel.Visible = settingsOpen
	player:SetAttribute("InGameSettingsOpen", settingsOpen)

	if settingsOpen then
		startMouseOverride()
		UserInputService.MouseIconEnabled = true
	else
		stopMouseOverride()
		UserInputService.MouseIconEnabled = false
	end
end

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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and settingsOpen then
		closeSettingsPanel()
	elseif input.KeyCode == Enum.KeyCode.B then
		toggleSettings()
	end
end)

-- ---------------------------------------------------------------------------
-- Lifecycle — react to InGame attribute
-- ---------------------------------------------------------------------------
local function onInGameChanged()
	local inGame = player:GetAttribute("InGame") == true
	inGameHUD.Enabled = inGame

	if inGame then
		closeSettingsPanel()
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
	end
end)

player.CharacterAdded:Connect(function(character)
	if player:GetAttribute("InGame") then
		watchHealth(character)
	end
end)

onInGameChanged()
