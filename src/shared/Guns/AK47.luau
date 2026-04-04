return {
	name = "AK47",
	autoFire = true,
	capacity = 30,
	damage = 50,
	range = 700,
	fireRate = 0.1,  -- ~600 RPM

	baseSpread = 1.2,
	rapidFireSpread = 3.0,
	movementSpread = 7.0,
	spreadDecayRate = 13.0,
	maxSpread = 8.0,

	adsSpeed = 0.2,
	adsMagnification = 2.2,
	adsSpreadMultiplier = 0.25,

	reloadTime = 2.4,
	spareAmmo = 150,

	recoilKick     = 0.05,
	recoilRotation = 3.0,
	recoilRecovery = 10,

	viewModelName = "AK47",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = -1,
	equipTime   = 0.4,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2.5,
	limbMultiplier     = 0.7,
}
