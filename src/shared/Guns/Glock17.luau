return {
	name = "Glock17",
	capacity = 17,
	damage = 30,
	range = 80,
	fireRate = 0.15,      -- seconds between shots (semi-auto, ~6/sec max)

	baseSpread = 2.0,     -- degrees, standing still, first shot
	rapidFireSpread = 1.5, -- extra degrees added per shot when firing fast
	movementSpread = 3.0, -- extra degrees while moving
	spreadDecayRate = 4.0, -- how fast rapidFire spread decays (degrees/sec)

	maxSpread = 8.0,      -- degrees, spread ceiling (reached ~shot 4-5 on rapid fire)

	adsSpeed = 0.12,          -- seconds to fully transition in/out
	adsMagnification = 1.3,   -- 1.3x zoom
	adsSpreadMultiplier = 0.5, -- 50% of normal spread while ADS

	reloadTime = 1.8,     -- seconds
	spareAmmo = 51,       -- 3 extra mags
}
