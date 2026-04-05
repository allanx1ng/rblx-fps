return {
	name = "M249",
	autoFire = true,
	capacity = 100,
	damage = 35,
	range = 600,
	fireRate = 0.075,  -- ~800 RPM

	baseSpread = 1.2,
	rapidFireSpread = 3.5,
	movementSpread = 8.0,
	spreadDecayRate = 10.0,
	maxSpread = 9.0,

	adsSpeed = 0.3,
	adsMagnification = 2.0,
	adsSpreadMultiplier = 0.35,

	reloadTime = 4.5,
	spareAmmo = 300,

	recoilKick     = 0.04,
	recoilRotation = 2.5,
	recoilRecovery = 9,

	viewModelName = "M249",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = -1,
	equipTime   = 0.5,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2,
	limbMultiplier     = 0.7,
}
