return {
	name = "Shotgun",
	pelletsPerShot = 10,
	capacity = 6,
	damage = 18,
	range = 100,
	fireRate = 0.4,

	baseSpread = 3.5,
	rapidFireSpread = 2,
	movementSpread = 2,
	spreadDecayRate = 8.0,
	maxSpread = 8.0,

	adsSpeed = 0.2,
	adsMagnification = 1.1,
	adsSpreadMultiplier = 0.8,

	reloadTime = 2.5,
	spareAmmo = 36,

	recoilKick     = 0.5,
	recoilRotation = -6,
	recoilRecovery = 8,

	viewModelName = "Shotgun",
	hipOffset = CFrame.new(0, -0.2, 0),
	adsDistance = 0.8,
	equipTime   = 0.4,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 1.5,
	limbMultiplier     = 0.75,

	-- Third-person view model
	thirdPersonPoseType = "rifle",
	thirdPersonGunOffset = Vector3.new(0.085, 0.491, -1.519),
}
