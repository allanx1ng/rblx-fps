-- Wires up the settings panel UI and persists settings to player Attributes.
-- Lives at: LobbyUI > SettingsController (LocalScript)
--
-- Sliders: tag a Frame with the setting tag (e.g. "SettingMasterVolume").
-- Expected children inside the slider frame:
--   Fill   (Frame)     — width scaled to current value
--   Value  (TextLabel) — displays current value (e.g. "75%")
--   The slider frame itself acts as the drag area.
--
-- Toggles: tag a GuiButton with the setting tag (e.g. "SettingFPSCounter").
-- Expected children inside the toggle button:
--   Indicator (Frame/ImageLabel) — visible when ON, hidden when OFF
--
-- All children are optional.
--
-- Supported tags:
--   Sliders:  SettingMasterVolume, SettingSFXVolume, SettingMusicVolume,
--             SettingMouseSensitivity
--   Toggles:  SettingFPSCounter

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- ---------------------------------------------------------------------------
-- Settings definitions
-- ---------------------------------------------------------------------------
local SLIDERS = {
	SettingMasterVolume     = { attr = "MasterVolume",     default = 100, min = 0, max = 100, suffix = "%" },
	-- SettingSFXVolume        = { attr = "SFXVolume",        default = 100, min = 0, max = 100, suffix = "%" },
	-- SettingMusicVolume      = { attr = "MusicVolume",      default = 100, min = 0, max = 100, suffix = "%" },
	SettingMouseSensitivity = { attr = "MouseSensitivity", default = 100, min = 0, max = 100, suffix = "%" },
}

local TOGGLES = {
	SettingFPSCounter = { attr = "FPSCounter", default = false },
}

-- ---------------------------------------------------------------------------
-- Initialize attributes with defaults (don't overwrite if already set)
-- ---------------------------------------------------------------------------
for _, config in SLIDERS do
	if player:GetAttribute(config.attr) == nil then
		player:SetAttribute(config.attr, config.default)
	end
end

for _, config in TOGGLES do
	if player:GetAttribute(config.attr) == nil then
		player:SetAttribute(config.attr, config.default)
	end
end

-- ---------------------------------------------------------------------------
-- Apply volume settings
-- ---------------------------------------------------------------------------
local function applyVolume()
	local master = (player:GetAttribute("MasterVolume") or 100) / 100
	SoundService.Volume = master

	-- Uncomment when SFX/Music SoundGroups are added:
	-- local sfx   = (player:GetAttribute("SFXVolume") or 100) / 100
	-- local music = (player:GetAttribute("MusicVolume") or 100) / 100
	-- local sfxGroup = SoundService:FindFirstChild("SFX")
	-- if sfxGroup then sfxGroup.Volume = sfx end
	-- local musicGroup = SoundService:FindFirstChild("Music")
	-- if musicGroup then musicGroup.Volume = music end
end

player.AttributeChanged:Connect(function(attr)
	if attr == "MasterVolume" then
		applyVolume()
	end
end)

applyVolume()

-- ---------------------------------------------------------------------------
-- Slider wiring
-- ---------------------------------------------------------------------------
local function updateSliderVisual(sliderFrame, config)
	local value = player:GetAttribute(config.attr) or config.default
	local normalized = (value - config.min) / (config.max - config.min)

	local fill = sliderFrame:FindFirstChild("Fill", true)
	if fill then
		fill.Size = UDim2.new(math.clamp(normalized, 0, 1), 0, 1, 0)
	end

	local valueLabel = sliderFrame:FindFirstChild("Value", true)
	if valueLabel then
		valueLabel.Text = tostring(math.floor(value)) .. config.suffix
	end
end

-- Update all slider visuals for a given tag when the attribute changes
local allSliders = {} -- { [attr] = { {frame, config}, ... } }

local function wireOneSlider(sliderFrame, config)
	updateSliderVisual(sliderFrame, config)

	local dragging = false

	local function updateFromMouse()
		local mousePos = UserInputService:GetMouseLocation()
		local absPos = sliderFrame.AbsolutePosition
		local absSize = sliderFrame.AbsoluteSize
		local normalized = math.clamp((mousePos.X - absPos.X) / absSize.X, 0, 1)
		local value = math.floor(config.min + normalized * (config.max - config.min))
		player:SetAttribute(config.attr, value)
	end

	sliderFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			updateFromMouse()
		end
	end)

	sliderFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		if dragging then
			updateFromMouse()
		end
	end)

	if not allSliders[config.attr] then
		allSliders[config.attr] = {}
	end
	table.insert(allSliders[config.attr], { frame = sliderFrame, config = config })
end

for tag, config in SLIDERS do
	for _, sliderFrame in CollectionService:GetTagged(tag) do
		wireOneSlider(sliderFrame, config)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(sliderFrame)
		wireOneSlider(sliderFrame, config)
	end)
end

-- Keep all slider visuals in sync when attribute changes
player.AttributeChanged:Connect(function(attr)
	if allSliders[attr] then
		for _, entry in allSliders[attr] do
			updateSliderVisual(entry.frame, entry.config)
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Toggle wiring
-- ---------------------------------------------------------------------------
local function updateToggleVisual(button, config)
	local value = player:GetAttribute(config.attr)
	if value == nil then value = config.default end

	local indicator = button:FindFirstChild("Indicator", true)
	if indicator then
		indicator.Visible = value
	end
end

local allToggles = {} -- { [attr] = { {button, config}, ... } }

local function wireOneToggle(button, config)
	if not button:IsA("GuiButton") then return end

	updateToggleVisual(button, config)

	button.Activated:Connect(function()
		local current = player:GetAttribute(config.attr)
		if current == nil then current = config.default end
		player:SetAttribute(config.attr, not current)
	end)

	if not allToggles[config.attr] then
		allToggles[config.attr] = {}
	end
	table.insert(allToggles[config.attr], { button = button, config = config })
end

for tag, config in TOGGLES do
	for _, button in CollectionService:GetTagged(tag) do
		wireOneToggle(button, config)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(button)
		wireOneToggle(button, config)
	end)
end

-- Keep all toggle visuals in sync when attribute changes
player.AttributeChanged:Connect(function(attr)
	if allToggles[attr] then
		for _, entry in allToggles[attr] do
			updateToggleVisual(entry.button, entry.config)
		end
	end
end)
