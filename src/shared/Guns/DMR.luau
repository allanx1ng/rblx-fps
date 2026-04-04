return {
	name = "DMR",
	autoFire = false,
	capacity = 15,
	damage = 65,
	range = 800,
	fireRate = 0.25,  -- ~240 RPM

	baseSpread = 0.8,
	rapidFireSpread = 5.0,
	movementSpread = 10.0,
	spreadDecayRate = 12.0,
	maxSpread = 12.0,

	adsSpeed = 0.25,
	adsMagnification = 4.0,
	adsSpreadMultiplier = 0.1,

	reloadTime = 2.2,
	spareAmmo = 75,

	recoilKick     = 0.12,
	recoilRotation = 3.5,
	recoilRecovery = 7,

	viewModelName = "DMR",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = -1,
	equipTime   = 0.4,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2.5,
	limbMultiplier     = 0.75,
}
