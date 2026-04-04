return {
	name = "M9",
	capacity = 20,
	damage = 20,
	range = 999,
	fireRate = 0.1,

	baseSpread = 1.5,
	rapidFireSpread = 4,
	movementSpread = 4.0,
	spreadDecayRate = 12.0,
	maxSpread = 10.0,

	adsSpeed = 0.15,
	adsMagnification = 1.1,
	adsSpreadMultiplier = 0.5,

	reloadTime = 1.0,
	spareAmmo = 60,  -- 3 extra mags

	viewModelName = "M9",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = 0.8,
	equipTime   = 0.35,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),  -- where arms start: right, below, back

	recoilKick     = 0.08,
	recoilRotation = 4,
	recoilRecovery = 14,

	headshotMultiplier = 1.5,
	limbMultiplier     = 0.5,
}
