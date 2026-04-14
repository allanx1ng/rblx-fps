return {
	name = "Sword",
	weaponType = "melee",
	isGun = false,

	-- Damage
	damage = 50,
	range = 10,              -- studs (raycast distance for hit detection)
	swingCooldown = 0.6,    -- seconds between swings
	hitDelay = 0.15,        -- seconds into animation before hit registers
	headshotMultiplier = 1, -- no headshot bonus for melee
	limbMultiplier = 1,

	-- View Model (first person)
	viewModelName = "Sword",
	hipOffset = CFrame.new(0.5, -0.5, -1.2),
	equipTime = 0.3,
	equipOffset = CFrame.new(0.2, -0.8, 0.3),
	recoilRecovery = 12,    -- reused by ViewModelController lerp

	-- Swing animation (procedural first-person keyframes)
	-- Each swing is a list of keyframes: { t = time fraction, pos = {x,y,z}, rot = {rx,ry,rz} degrees }
	-- Alternating swings cycle through the list for variety.
	swingDuration = 0.4,
	swingAnimations = {
		-- Swing 1: right-to-left diagonal slash
		{
			{ t = 0.0,  pos = {0, 0, 0},        rot = {0, 0, 0} },        -- idle
			{ t = 0.15, pos = {0.3, 0.2, 0.1},  rot = {-20, 15, -10} },   -- wind-up right
			-- { t = 0.35, pos = {-0.2, -0.1, -0.2}, rot = {30, -25, 15} },  -- slash left-down
			-- { t = 0.55, pos = {-0.3, -0.2, -0.1}, rot = {35, -30, 20} },  -- follow-through
			{ t = 1.0,  pos = {0, 0, 0},        rot = {0, 0, 0} },        -- return to idle
		},
		-- Swing 2: left-to-right diagonal slash
		{
			{ t = 0.0,  pos = {0, 0, 0},        rot = {0, 0, 0} },
			{ t = 0.15, pos = {-0.3, 0.2, 0.1}, rot = {-20, -15, 10} },   -- wind-up left
			-- { t = 0.35, pos = {0.2, -0.1, -0.2}, rot = {30, 25, -15} },   -- slash right-down
			-- { t = 0.55, pos = {0.3, -0.2, -0.1}, rot = {35, 30, -20} },   -- follow-through
			{ t = 1.0,  pos = {0, 0, 0},        rot = {0, 0, 0} },        -- return to idle
		},
		-- Swing 3: overhead chop
		-- {
		-- 	{ t = 0.0,  pos = {0, 0, 0},        rot = {0, 0, 0} },
		-- 	{ t = 0.15, pos = {0, 0.4, 0.15},   rot = {-35, 0, 0} },      -- raise up
		-- 	{ t = 0.35, pos = {0, -0.15, -0.25}, rot = {40, 0, 0} },      -- chop down
		-- 	{ t = 0.55, pos = {0, -0.25, -0.15}, rot = {45, 0, 5} },      -- follow-through
		-- 	{ t = 1.0,  pos = {0, 0, 0},        rot = {0, 0, 0} },        -- return to idle
		-- },
	},

	-- Third person
	slashAnimationId = "http://www.roblox.com/asset/?id=129967390", -- default R6 toolslash
	thirdPersonGripOffset = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0),
}
