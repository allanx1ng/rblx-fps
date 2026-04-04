return {
	name = "Minigun",
	autoFire = true,
	capacity = 200,
	damage = 20,
	range = 500,
	fireRate = 0.04,  -- ~1500 RPM

	baseSpread = 3.0,
	rapidFireSpread = 4.0,
	movementSpread = 6.0,
	spreadDecayRate = 8.0,
	maxSpread = 10.0,

	adsSpeed = 0.4,
	adsMagnification = 1.5,
	adsSpreadMultiplier = 0.5,

	reloadTime = 5.0,
	spareAmmo = 600,

	recoilKick     = 0.01,
	recoilRotation = 1.0,
	recoilRecovery = 12,

	viewModelName = "Minigun",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = -1,
	equipTime   = 0.6,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 1.5,
	limbMultiplier     = 0.6,
}
