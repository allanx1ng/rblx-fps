return {
	name = "MP5",
	autoFire = true,
	capacity = 30,
	damage = 25,
	range = 400,
	fireRate = 0.075,  -- ~800 RPM

	baseSpread = 1.2,
	rapidFireSpread = 1.4,
	movementSpread = 4.0,
	spreadDecayRate = 15.0,
	maxSpread = 3.0,

	adsSpeed = 0.14,
	adsMagnification = 1.3,
	adsSpreadMultiplier = 0.5,

	reloadTime = 1.8,
	spareAmmo = 150,

	recoilKick     = 0.02,
	recoilRotation = 1.4,
	recoilRecovery = 14,

	viewModelName = "MP5",
	hipOffset = CFrame.new(0.5, -0.4, -0.9),
	adsDistance = -1,
	equipTime   = 0.35,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2,
	limbMultiplier     = 0.6,
}
