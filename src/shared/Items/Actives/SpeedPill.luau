return {
	name = "SpeedPill",
	displayName = "Speed Pill",
	description = "Infinite stamina and +100% move speed for 20 seconds.",
	category = "active",

	bonusSpeedFraction = 1.0,   -- +100% walk and sprint speed
	infiniteStamina = true,
	duration = 20,
	cooldown = 30,

	viewModelName = "SpeedPill",
	hipOffset = CFrame.new(0.5, -0.5, -0.8),
	adsDistance = 0,
	adsSpeed = 0.2,
	equipTime = 0.3,
	equipOffset = CFrame.new(0.2, -0.8, 0.2),
}
