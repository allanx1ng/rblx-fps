return {
	name = "M4",
	autoFire = true,
	capacity = 100,
	damage = 40,
	range = 800,
	fireRate = 0.09,  -- ~650 RPM
	pierceCount = 1,

	baseSpread = 0.5,
	rapidFireSpread = 1.8,
	movementSpread = 5.0,
	spreadDecayRate = 16.0,
	maxSpread = 6.0,

	adsSpeed = 0.18,
	adsMagnification = 2.5,
	adsSpreadMultiplier = 0.2,

	reloadTime = 2.2,
	spareAmmo = 1000,  -- 6 extra mags

	recoilKick     = 0.03,
	recoilRotation = 2.0,
	recoilRecovery = 12,

	viewModelName = "M4",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = -1,
	equipTime   = 0.4,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2.5,
	limbMultiplier     = 0.75,

	-- Third-person view model
	thirdPersonPoseType = "rifle",
	thirdPersonGunOffset = Vector3.new(0.056, 0.512, -1.591),
}
