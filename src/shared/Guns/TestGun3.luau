return {
	name = "TestGun3",
	autoFire = true,
	capacity = 100,
	damage = 40,
	range = 800,
	fireRate = 0.09,  -- ~650 RPM

	baseSpread = 0.6,
	rapidFireSpread = 2,
	movementSpread = 4.0,
	spreadDecayRate = 15.0,
	maxSpread = 5.5,

	adsSpeed = 0.18,
	adsMagnification = 1.3,
	adsSpreadMultiplier = 0.35,

	reloadTime = 2.2,
	spareAmmo = 1000,  -- 6 extra mags

	recoilKick     = 0.35,
	recoilRotation = -3.0,
	recoilRecovery = 12,

	viewModelName = "TestGun3",
	hipOffset = CFrame.new(0, -0.2, 0),
	adsDistance = 0.8,
	equipTime   = 0.4,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2.5,
	limbMultiplier     = 0.75,
	-- 0.159, 0.537, -1.502
}
