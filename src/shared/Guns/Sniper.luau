return {
	name = "Sniper",
	autoFire = false,
	capacity = 100,
	damage = 150,
	range = 800,
	fireRate = 1,  -- ~650 RPM

	baseSpread = 2,
	rapidFireSpread = 10,
	movementSpread = 5.0,
	spreadDecayRate = 7.0,
	maxSpread = 15.0,

	adsSpeed = 0.7,
	adsMagnification = 12,
	adsSpreadMultiplier = 0.02,

	reloadTime = 2.2,
	spareAmmo = 1000,  -- 6 extra mags

	recoilKick     = 1.0,
	recoilRotation = 4.5,
	recoilRecovery = 3.5,

	viewModelName = "Sniper",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = 0,
	equipTime   = 0.4,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 3,
	limbMultiplier     = 0.75,

	-- Third-person view model
	thirdPersonPoseType = "rifle",
	thirdPersonGunOffset = Vector3.new(0.104, 0.352, -1.815),
}
