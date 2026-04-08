return {
	name = "Minigun",
	autoFire = true,
	capacity = 300,
	damage = 50,
	range = 500,
	fireRate = 0.03,  -- ~2000 RPM

	baseSpread = 1.5,
	rapidFireSpread = 0.35,
	movementSpread = 1.0,
	spreadDecayRate = 8.0,
	maxSpread = 3.0,

	adsSpeed = 1,
	adsMagnification = 1,
	adsSpreadMultiplier = 1,

	reloadTime = 5.0,
	spareAmmo = 1000,

	recoilKick     = 0.01,
	recoilRotation = 1.0,
	recoilRecovery = 12,

	viewModelName = "Minigun",
	-- hipOffset = CFrame.new(-1.5, 0.5, -1),
	hipOffset = CFrame.new(-0.2,-0.7,-1),
	adsDistance = -1,
	equipTime   = 0.6,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2,
	limbMultiplier     = 0.8,

	-- Third-person view model
	thirdPersonPoseType = "rifle",
	thirdPersonGunOffset = Vector3.new(-0.418, 0.32, -0.377),
}
