return {
	name = "Sword",
	weaponType = "melee",
	isGun = false,

	-- Damage
	damage = 50,
	range = 8,              -- studs (raycast distance for hit detection)
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

	-- Swing animation (procedural first-person)
	swingDuration = 0.4,

	-- Third person
	slashAnimationId = "rbxassetid://522635514", -- default Roblox slash
	thirdPersonGripOffset = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0),
}
