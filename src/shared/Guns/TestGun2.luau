return {
	name = "TestGun2",
	autoFire = true,
	capacity = 100,
	damage = 20,
	range = 999,
	fireRate = 0.1,

	baseSpread = 1.5,
	rapidFireSpread = 4,
	movementSpread = 3.5,
	spreadDecayRate = 12.0,
	maxSpread = 10.0,

	adsSpeed = 0.15,
	adsMagnification = 1.1,
	adsSpreadMultiplier = 0.5,

	reloadTime = 1.5,
	spareAmmo = 900,  -- 3 extra mags

	recoilKick     = 0.08,
	recoilRotation = 4,
	recoilRecovery = 14,

	viewModelName = "TestGun2",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = 0.8,
	equipTime   = 0.35,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 1.5,
	limbMultiplier     = 0.5,
}
