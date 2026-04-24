return {
	name = "Uzi",
	autoFire = true,
	capacity = 32,
	damage = 22,
	range = 300,
	fireRate = 0.06,  -- ~1000 RPM

	baseSpread = 1.0,
	rapidFireSpread = 2.0,
	movementSpread = 3.5,
	spreadDecayRate = 14.0,
	maxSpread = 6.0,

	adsSpeed = 0.12,
	adsMagnification = 1.2,
	adsSpreadMultiplier = 0.6,

	reloadTime = 1.5,
	spareAmmo = 160,

	recoilKick     = 0.4,
	recoilRotation = -1.0,
	recoilRecovery = 15,

	viewModelName = "Uzi",
	hipOffset = CFrame.new(0, -0.2, 0),
	adsDistance = 0.8,
	equipTime   = 0.3,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 1.8,
	limbMultiplier     = 0.6,

	-- Third-person view model
	thirdPersonPoseType = "pistol",
	thirdPersonGunOffset = Vector3.new(-0.198, 0.482, -0.779),
}
