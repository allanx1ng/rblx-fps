return {
	name = "Desert Eagle",
	autoFire = false,
	capacity = 7,
	damage = 70,
	range = 500,
	fireRate = 0.35,  -- ~170 RPM

	baseSpread = 0.9,
	rapidFireSpread = 7.0,
	movementSpread = 6.0,
	spreadDecayRate = 12.0,
	maxSpread = 10.0,

	adsSpeed = 0.17,
	adsMagnification = 1.3,
	adsSpreadMultiplier = 0.6,

	reloadTime = 2.0,
	spareAmmo = 42,

	recoilKick     = 0.5,
	recoilRotation = -6.0,
	recoilRecovery = 7,

	viewModelName = "Deagle",
	hipOffset = CFrame.new(0.5, -0.4, -0.9),
	adsDistance = 0.8,
	equipTime   = 0.35,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2.5,
	limbMultiplier     = 0.7,

	-- Third-person view model
	thirdPersonPoseType = "pistol",
	thirdPersonGunOffset = Vector3.new(-0.371, -0.739, -1.052),
}
