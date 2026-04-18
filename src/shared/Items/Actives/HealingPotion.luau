return {
	name = "HealingPotion",
	displayName = "Healing Potion",
	description = "Instantly heal 50 HP. 10 second cooldown.",
	category = "active",

	healAmount = 50,
	healToFull = false,
	cooldown = 10,
	maxUses = 2,

	-- Use animation: raise to mouth and tilt
	useDuration = 0.6,
	useOffset = CFrame.new(0, 0.3, -0.3) * CFrame.Angles(math.rad(-40), 0, 0),

	-- ViewModel settings
	viewModelName = "HealingPotion",
	hipOffset = CFrame.new(0.5, -0.5, -0.8),
	adsDistance = 0,
	adsSpeed = 0.2,
	equipTime = 0.3,
	equipOffset = CFrame.new(0.2, -0.8, 0.2),
}
