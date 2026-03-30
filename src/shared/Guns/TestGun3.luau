return {
	name = "TestGun3",
	autoFire = true,
	capacity = 100,
	damage = 25,
	range = 800,
	fireRate = 0.09,  -- ~650 RPM

	baseSpread = 1.2,
	rapidFireSpread = 2,
	movementSpread = 6.0,
	spreadDecayRate = 16.0,
	maxSpread = 6.0,

	adsSpeed = 0.18,
	adsMagnification = 1.3,
	adsSpreadMultiplier = 0.3,

	reloadTime = 2.2,
	spareAmmo = 1000,  -- 6 extra mags

	recoilKick     = 0.06,
	recoilRotation = 3.5,
	recoilRecovery = 12,

	viewModelName = "TestGun3",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = 0.8,
	equipTime   = 0.4,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 3,
	limbMultiplier     = 0.5,
}
