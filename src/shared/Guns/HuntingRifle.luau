return {
	name = "HuntingRifle",
	autoFire = false,
	capacity = 5,
	damage = 120,
	range = 900,
	fireRate = 1.2,

	baseSpread = 1.4,
	rapidFireSpread = 12,
	movementSpread = 18.0,
	spreadDecayRate = 8.0,
	maxSpread = 18.0,

	adsSpeed = 0.6,
	adsMagnification = 8,
	adsSpreadMultiplier = 0.01,

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

	headshotMultiplier = 3,
	limbMultiplier     = 0.7,

	-- Third-person view model
	thirdPersonPoseType = "rifle",
	thirdPersonGunOffset = Vector3.new(-0.418, 0.32, -0.377),
}
