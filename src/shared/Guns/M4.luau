return {
	name = "M4",
	capacity = 30,
	damage = 25,
	range = 150,
	fireRate = 0.09,       -- ~660 rpm, full auto

	baseSpread = 1.2,
	rapidFireSpread = 2.5, -- builds up heavily on sustained fire
	movementSpread = 2.8,
	spreadDecayRate = 3.5,

	maxSpread = 11.2,      -- degrees, plateau hit around bullet 5-6

	adsSpeed = 0.18,
	adsMagnification = 1.5,    -- 1.5x zoom
	adsSpreadMultiplier = 0.35,

	reloadTime = 2.5,
	spareAmmo = 90,  -- 3 extra mags
}
