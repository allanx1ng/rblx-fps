return {
	name = "Revolver",
	autoFire = false,
	capacity = 6,
	damage = 55,
	range = 500,
	fireRate = 0.4,  -- ~150 RPM

	baseSpread = 0.9,
	rapidFireSpread = 6.0,
	movementSpread = 5.0,
	spreadDecayRate = 10.0,
	maxSpread = 8.0,

	adsSpeed = 0.16,
	adsMagnification = 1.2,
	adsSpreadMultiplier = 0.6,

	reloadTime = 2.5,
	spareAmmo = 48,

	recoilKick     = 0.5,
	recoilRotation = -5.0,
	recoilRecovery = 8,

	viewModelName = "Revolver",
	hipOffset = CFrame.new(0.5, -0.4, -0.9),
	adsDistance = -1,
	equipTime   = 0.4,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2,
	limbMultiplier     = 0.75,

	-- Third-person view model
	thirdPersonPoseType = "pistol",
	thirdPersonGunOffset = Vector3.new(-0.219, 0.515, -0.883),
}
