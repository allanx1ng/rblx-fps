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
	-- Offsets from camera CFrame. Tune these in-game until it looks right.
	-- Positive X = right, negative Y = down, negative Z = forward
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsOffset = CFrame.new(0, -0.3, -0.8),
}
