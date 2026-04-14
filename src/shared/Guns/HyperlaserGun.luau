return {
	name = "HyperlaserGun",
	firingMode = "projectile",
	projectileSpeed = 160,
	projectileSize = Vector3.new(0.2, 0.2, 3),
	projectileColor = Color3.fromRGB(0, 255, 255),
	projectileLight = true,
	projectileLightBrightness = 1,
	projectileLightRange = 16,
	autoFire = true,
	capacity = 20,
	damage = 100,
	range = 800,
	fireRate = 0.2,
	pierceCount = 4, 

	baseSpread = 0,
	rapidFireSpread = 0,
	movementSpread = 0,
	spreadDecayRate = 16.0,
	maxSpread = 0.0,

	adsSpeed = 0.2,
	adsMagnification = 1.3,
	adsSpreadMultiplier = 0.5,

	reloadTime = 1.2,
	spareAmmo = 500, 

	recoilKick     = 0,
	recoilRotation = 0,
	recoilRecovery = 0,

	viewModelName = "HyperlaserGun",
	hipOffset = CFrame.new(0.5, -0.4, -1.0),
	adsDistance = 0.8,
	equipTime   = 0.4,
	equipOffset = CFrame.new(0.2, -0.6, 0.3),

	headshotMultiplier = 2,
	limbMultiplier     = 0.75,

	-- Third-person view model
	thirdPersonPoseType = "pistol",
	thirdPersonGunOffset = Vector3.new(-0.314, 0.434, -1.258),
}
