-- Lighting presets for lobby vs in-game atmospheres.
--
-- Applied client-side (see src/client/LightingController.luau) so each player
-- can see a different atmosphere in the same shared world based on their
-- InGame attribute. game.Lighting is a global service, but LocalScript edits
-- only affect that client's view.
--
-- Tweak numbers here; the controller tweens between presets on transition.

local Color = Color3.fromRGB

return {
	-- Bright, safe, clean. Daytime lobby vibe.
	-- Lobby = {
	-- 	ClockTime               = 14,
	-- 	GeographicLatitude      = 41,
	-- 	Ambient                 = Color(130, 135, 140),
	-- 	OutdoorAmbient          = Color(160, 165, 170),
	-- 	Brightness              = 2,
	-- 	ColorShift_Top          = Color(0, 0, 0),
	-- 	ColorShift_Bottom       = Color(0, 0, 0),
	-- 	EnvironmentDiffuseScale = 1,
	-- 	EnvironmentSpecularScale = 1,
	-- 	ExposureCompensation    = 0,
	-- 	GlobalShadows           = true,
	-- 	ShadowSoftness          = 0.2,

	-- 	FogColor = Color(200, 210, 220),
	-- 	FogStart = 500,
	-- 	FogEnd   = 5000, -- effectively clear

	-- 	Atmosphere = {
	-- 		Density = 0.1,
	-- 		Offset  = 0,
	-- 		Color   = Color(199, 199, 199),
	-- 		Decay   = Color(106, 112, 125),
	-- 		Glare   = 0,
	-- 		Haze    = 0,
	-- 	},

	-- 	ColorCorrection = {
	-- 		Brightness  = 0,
	-- 		Contrast    = 0,
	-- 		Saturation  = 0,
	-- 		TintColor   = Color(255, 255, 255),
	-- 	},

	-- 	Bloom = {
	-- 		Intensity = 0.2,
	-- 		Size      = 24,
	-- 		Threshold = 0.95,
	-- 	},
	-- },

	Lobby = {
		ClockTime               = 0,   -- dead of night
		GeographicLatitude      = 41,
		Ambient                 = Color(70,70,70),
		OutdoorAmbient          = Color(70,70,70),
		Brightness              = 5,
		ColorShift_Top          = Color(0,0,0),
		ColorShift_Bottom       = Color(0,0,0),
		EnvironmentDiffuseScale = 0.3,
		EnvironmentSpecularScale = 0.3,
		ExposureCompensation    = 0,
		GlobalShadows           = false,
		ShadowSoftness          = 0.5,

		FogColor = Color(14, 16, 22),
		FogStart = 25,
		FogEnd   = 300,

		Atmosphere = {
			Density = 0.5,
			Offset  = 0.25,
			Color   = Color(40,40,40),
			Decay   = Color(0,0,0),
			Glare   = 0.2,
			Haze    = 0.5,
		},

		-- Brightness slider range: values at 0% and 100%
		BrightnessScale = {
			Min = {
				Ambient        = Color(0,0,0),
				OutdoorAmbient = Color(10,10,10),
				FogColor       = Color(0,0,0),
			},
			Max = {
				Ambient        = Color(120,120,120),
				OutdoorAmbient = Color(150, 150, 150),
				FogColor       = Color(40,40,40),
			},
		},

		ColorCorrection = {
			Brightness  = 0,
			Contrast    = 0,
			Saturation  = -0.35,
			TintColor   = Color(200, 215, 230),
			Enabled = false
		},

		Bloom = {
			Intensity = 0.6,
			Size      = 24,
			Threshold = 2,
		},
	},

	-- Dark, foggy, cold — zombie survival atmosphere.
	Game = {
		ClockTime               = 0,   -- dead of night
		GeographicLatitude      = 41,
		Ambient                 = Color(70,70,70),
		OutdoorAmbient          = Color(100,100,100),
		Brightness              = 5,
		ColorShift_Top          = Color(0,0,0),
		ColorShift_Bottom       = Color(0,0,0),
		EnvironmentDiffuseScale = 0.3,
		EnvironmentSpecularScale = 0.3,
		ExposureCompensation    = 0,
		GlobalShadows           = false,
		ShadowSoftness          = 0.5,

		FogColor = Color(20,20,20),
		FogStart = 25,
		FogEnd   = 300,

		Atmosphere = {
			Density = 0.5,
			Offset  = 0.25,
			Color   = Color(40,40,40),
			Decay   = Color(0,0,0),
			Glare   = 0.2,
			Haze    = 0.2,
		},

		-- Brightness slider range: values at 0% and 100%
		BrightnessScale = {
			Min = {
				Ambient        = Color(0,0,0),
				OutdoorAmbient = Color(10,10,10),
				FogColor       = Color(0,0,0),
			},
			Max = {
				Ambient        = Color(120,120,120),
				OutdoorAmbient = Color(130,130,130),
				FogColor       = Color(40,40,40),
			},
		},

		ColorCorrection = {
			Brightness  = 0,
			Contrast    = 0,
			Saturation  = -0.35,
			TintColor   = Color(200, 215, 230),
			Enabled = false
		},

		Bloom = {
			Intensity = 0.6,
			Size      = 24,
			Threshold = 2,
		},
	},
}
