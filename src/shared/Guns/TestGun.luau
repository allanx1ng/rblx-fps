return {
	name = "TestGun",
	capacity = 20,
	damage = 25,
	range = 200,
	fireRate = 0.1,

	baseSpread = 1.5,
	rapidFireSpread = 4,
	movementSpread = 4.0,
	spreadDecayRate = 12.0,
	maxSpread = 8.0,

	adsSpeed = 0.15,
	adsMagnification = 1.5,
	adsSpreadMultiplier = 0.5,

	reloadTime = 1.0,
	spareAmmo = 60,  -- 3 extra mags

	viewModelName = "TestGun",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = 0.8,

	recoilKick     = 0.08,  -- studs the gun snaps back toward camera per shot
	recoilRotation = 4,     -- degrees the gun rotates upward per shot
	recoilRecovery = 14,    -- lerp speed back to rest; higher = snappier
}
