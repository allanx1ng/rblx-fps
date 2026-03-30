return {
	-- Health
	maxHealth       = 100,
	healthRegenRate = 1,    -- HP per second
	healthRegenDelay = 6,   -- seconds after taking damage before regen starts

	-- Stamina
	maxStamina        = 100,
	staminaDrainRate  = 20,  -- stamina per second while sprinting
	staminaRegenRate  = 15,  -- stamina per second while not sprinting
	staminaRegenDelay = 1.5, -- seconds after sprinting stops before regen starts

	-- Movement
	walkSpeed   = 16,
	sprintSpeed = 26,
	crouchSpeed = 8,
}
