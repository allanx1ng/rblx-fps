return {
	name = "Revolver",
	autoFire = false,
	capacity = 6,
	damage = 55,
	range = 500,
	fireRate = 0.4,  -- ~150 RPM

	baseSpread = 1.3,
	rapidFireSpread = 6.0,
	movementSpread = 5.0,
	spreadDecayRate = 8.0,
	maxSpread = 8.0,

	adsSpeed = 0.16,
	adsMagnification = 1.2,
	adsSpreadMultiplier = 0.5,

	reloadTime = 2.5,
	spareAmmo = 48,

	recoilKick     = 0.06,
	recoilRotation = 5.0,
	recoilRecovery = 8,

	viewModelName = "Revolver",
	hipOffset = CFrame.new(0.5, -0.4, -0.9),
	adsDistance = -1,
	equipTime   = 0.4,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2,
	limbMultiplier     = 0.7,
}
