return {
	name = "RPG",
	firingMode = "explosive_projectile",
	autoFire = false,
	capacity = 1,
	damage = 500,  -- reference only; actual damage is tiered via blastTiers
	range = 500,
	fireRate = 0.5,

	baseSpread = 0,
	rapidFireSpread = 0,
	movementSpread = 0,
	spreadDecayRate = 0,
	maxSpread = 0,

	adsSpeed = 0.25,
	adsMagnification = 2.0,
	adsSpreadMultiplier = 1,

	reloadTime = 3.0,
	spareAmmo = 20,

	recoilKick     = 0.6,
	recoilRotation = -4.0,
	recoilRecovery = 6,

	viewModelName = "RPG",
	hipOffset = CFrame.new(0, -0.2, 0),
	adsDistance = -1,
	equipTime   = 0.5,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 1,
	limbMultiplier     = 1,

	-- Third-person view model
	thirdPersonPoseType = "rifle",
	thirdPersonGunOffset = Vector3.new(-0.151, -0.004, -0.8),

	-- Projectile
	projectileSpeed = 150,
	-- Fallback visuals if Projectile part not found in weapon model
	projectileSize = Vector3.new(0.3, 0.3, 1.5),
	projectileColor = Color3.fromRGB(80, 80, 80),

	-- Explosion — tiered damage by distance (must be sorted by radius ascending)
	blastTiers = {
		{ radius = 10, damage = 500 },
		{ radius = 20, damage = 300 },
		{ radius = 25, damage = 200 },
		{ radius = 30, damage = 100 },
		{ radius = 40, damage = 50 },
	},
}
