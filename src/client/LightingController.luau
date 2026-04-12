-- Applies lobby vs game lighting presets client-side based on the player's
-- InGame attribute (owned by GameStateManager on the server).
--
-- Because this runs in a LocalScript, property writes to game.Lighting are
-- client-only — each player sees the atmosphere for their current state even
-- though all players share one world.

local Lighting          = game:GetService("Lighting")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Presets = require(ReplicatedStorage.Shared.LightingPresets)

local TRANSITION_TIME = 1.2
local TWEEN_INFO = TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local player = Players.LocalPlayer

-- ---------------------------------------------------------------------------
-- Effect instances — created once, reused across preset swaps
-- ---------------------------------------------------------------------------
local function getOrCreate(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

local atmosphere      = getOrCreate("Atmosphere",      "GameAtmosphere")
local colorCorrection = getOrCreate("ColorCorrectionEffect", "GameColorCorrection")
local bloom           = getOrCreate("BloomEffect",     "GameBloom")

-- ---------------------------------------------------------------------------
-- Tween helpers
-- ---------------------------------------------------------------------------
local function tweenProps(instance, props)
	TweenService:Create(instance, TWEEN_INFO, props):Play()
end

-- ClockTime can't be tweened directly (not a tweenable property on Lighting in
-- all contexts). Manually lerp it over the same duration.
local function tweenClockTime(target)
	local start = Lighting.ClockTime
	local t0 = tick()
	task.spawn(function()
		while true do
			local alpha = math.min((tick() - t0) / TRANSITION_TIME, 1)
			Lighting.ClockTime = start + (target - start) * alpha
			if alpha >= 1 then break end
			task.wait()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Apply a preset
-- ---------------------------------------------------------------------------
local function applyPreset(preset)
	-- Non-tweenable or categorical properties: set directly
	Lighting.GlobalShadows      = preset.GlobalShadows
	Lighting.GeographicLatitude = preset.GeographicLatitude

	tweenClockTime(preset.ClockTime)

	tweenProps(Lighting, {
		Ambient                  = preset.Ambient,
		OutdoorAmbient           = preset.OutdoorAmbient,
		Brightness               = preset.Brightness,
		ColorShift_Top           = preset.ColorShift_Top,
		ColorShift_Bottom        = preset.ColorShift_Bottom,
		EnvironmentDiffuseScale  = preset.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = preset.EnvironmentSpecularScale,
		ExposureCompensation     = preset.ExposureCompensation,
		ShadowSoftness           = preset.ShadowSoftness,
		FogColor                 = preset.FogColor,
		FogStart                 = preset.FogStart,
		FogEnd                   = preset.FogEnd,
	})

	tweenProps(atmosphere, {
		Density = preset.Atmosphere.Density,
		Offset  = preset.Atmosphere.Offset,
		Color   = preset.Atmosphere.Color,
		Decay   = preset.Atmosphere.Decay,
		Glare   = preset.Atmosphere.Glare,
		Haze    = preset.Atmosphere.Haze,
	})

	tweenProps(colorCorrection, {
		Brightness = preset.ColorCorrection.Brightness,
		Contrast   = preset.ColorCorrection.Contrast,
		Saturation = preset.ColorCorrection.Saturation,
		TintColor  = preset.ColorCorrection.TintColor,
	})

	tweenProps(bloom, {
		Intensity = preset.Bloom.Intensity,
		Size      = preset.Bloom.Size,
		Threshold = preset.Bloom.Threshold,
	})
end

-- ---------------------------------------------------------------------------
-- Drive from InGame attribute
-- ---------------------------------------------------------------------------
local function refresh()
	local inGame = player:GetAttribute("InGame")
	applyPreset(inGame and Presets.Game or Presets.Lobby)
end

player:GetAttributeChangedSignal("InGame"):Connect(refresh)
refresh()

return {}
