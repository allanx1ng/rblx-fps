return {
	name = "Deagle",
	autoFire = false,
	capacity = 7,
	damage = 70,
	range = 500,
	fireRate = 0.35,  -- ~170 RPM

	baseSpread = 1.3,
	rapidFireSpread = 7.0,
	movementSpread = 6.0,
	spreadDecayRate = 9.0,
	maxSpread = 10.0,

	adsSpeed = 0.17,
	adsMagnification = 1.3,
	adsSpreadMultiplier = 0.45,

	reloadTime = 2.0,
	spareAmmo = 42,

	recoilKick     = 0.1,
	recoilRotation = 6.0,
	recoilRecovery = 7,

	viewModelName = "Deagle",
	hipOffset = CFrame.new(0.5, -0.4, -0.9),
	adsDistance = 0.8,
	equipTime   = 0.35,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2.5,
	limbMultiplier     = 0.7,
}
