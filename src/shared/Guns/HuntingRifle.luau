return {
	name = "HuntingRifle",
	autoFire = false,
	capacity = 5,
	damage = 75,
	range = 900,
	fireRate = 0.5,
	pierceCount = 1,

	baseSpread = 1.0,
	rapidFireSpread = 6,
	movementSpread = 4.0,
	spreadDecayRate = 9.0,
	maxSpread = 10.0,

	adsSpeed = 0.4,
	adsMagnification = 1.5,
	adsSpreadMultiplier = 0.2,

	reloadTime = 2.8,
	spareAmmo = 30,

	recoilKick     = 0.8,
	recoilRotation = 5.0,
	recoilRecovery = 3.0,

	viewModelName = "HuntingRifle",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = 0,
	equipTime   = 0.45,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2,
	limbMultiplier     = 0.7,

	-- Third-person view model
	thirdPersonPoseType = "rifle",
	thirdPersonGunOffset = Vector3.new(-0.418, 0.32, -0.377),
}
