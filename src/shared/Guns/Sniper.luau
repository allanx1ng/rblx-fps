return {
	name = "Sniper",
	capacity = 6,
	damage = 95,
	range = 500,
	fireRate = 1.2,        -- bolt action

	baseSpread = 0.2,      -- very tight when stationary
	rapidFireSpread = 3.0, -- punishing if you fire again immediately
	movementSpread = 8.0,  -- nearly useless while moving
	spreadDecayRate = 2.0, -- slow recovery

	maxSpread = 12.0,     -- degrees, mostly irrelevant given the slow fire rate

	adsSpeed = 0.3,
	adsMagnification = 4.0,    -- 4x scope
	adsSpreadMultiplier = 0.1, -- nearly pinpoint while scoped and stationary

	reloadTime = 3.5,
	spareAmmo = 18,  -- 3 extra mags
}
