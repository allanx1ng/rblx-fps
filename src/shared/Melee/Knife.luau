return {
	name = "Knife",
	weaponType = "melee",
	isGun = false,

	-- Damage
	damage = 35,
	range = 8,              -- studs (shorter than sword)
	swingCooldown = 0.35,   -- seconds between swings (faster than sword)
	hitDelay = 0.1,         -- seconds into animation before hit registers
	headshotMultiplier = 1,
	limbMultiplier = 1,

	-- View Model (first person)
	viewModelName = "Knife",
	hipOffset = CFrame.new(0.4, -0.4, -0.8),
	equipTime = 0.2,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),
	recoilRecovery = 14,

	-- Swing animation (procedural first-person keyframes)
	swingDuration = 0.3,
	swingAnimations = {
		-- Swing 1: quick right stab
		{
			{ t = 0.0,  pos = {0, 0, 0},         rot = {0, 0, 0} },
			{ t = 0.1,  pos = {0.1, 0.05, 0.1},  rot = {-10, 5, 0} },     -- pull back
			{ t = 0.35, pos = {-0.05, 0, -0.35}, rot = {15, -5, 0} },     -- stab forward
			{ t = 0.6,  pos = {-0.05, 0, -0.3},  rot = {12, -3, 0} },     -- hold
			{ t = 1.0,  pos = {0, 0, 0},         rot = {0, 0, 0} },
		},
		-- Swing 2: left slash
		{
			{ t = 0.0,  pos = {0, 0, 0},         rot = {0, 0, 0} },
			{ t = 0.1,  pos = {-0.15, 0.1, 0.05}, rot = {-8, -10, 5} },   -- wind left
			{ t = 0.35, pos = {0.15, -0.05, -0.15}, rot = {10, 15, -8} },  -- slash right
			{ t = 0.6,  pos = {0.1, -0.05, -0.1}, rot = {8, 12, -5} },    -- follow-through
			{ t = 1.0,  pos = {0, 0, 0},         rot = {0, 0, 0} },
		},
		-- Swing 3: right slash
		{
			{ t = 0.0,  pos = {0, 0, 0},         rot = {0, 0, 0} },
			{ t = 0.1,  pos = {0.15, 0.1, 0.05}, rot = {-8, 10, -5} },    -- wind right
			{ t = 0.35, pos = {-0.15, -0.05, -0.15}, rot = {10, -15, 8} }, -- slash left
			{ t = 0.6,  pos = {-0.1, -0.05, -0.1}, rot = {8, -12, 5} },   -- follow-through
			{ t = 1.0,  pos = {0, 0, 0},         rot = {0, 0, 0} },
		},
	},

	-- Third person
	slashAnimationId = "http://www.roblox.com/asset/?id=129967390", -- default R6 toolslash
	thirdPersonGripOffset = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0),
}
