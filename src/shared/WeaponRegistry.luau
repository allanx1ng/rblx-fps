-- Defines display order, slot assignment, and unlock requirements for all weapons.
-- This is the single source of truth for what appears in the loadout UI.
--
-- Fields:
--   name         — must match the config module name in Guns/
--   displayName  — shown in UI
--   slot         — "primary" | "secondary" | "melee"
--   unlockLevel  — minimum player level to use (0 = always available)
--   unlockCost   — gold cost to purchase (0 = free)
--   robuxCost    — Robux cost to purchase (0 = not a Robux item)
--                   When robuxCost > 0, the item is purchased with Robux instead of gold.
--   description  — short flavour text for the UI

return {
	primary = {
		{ name = "M4",            displayName = "M4 Carbine",    unlockLevel = 0,  unlockCost = 1,     robuxCost = 0, description = "Full-auto assault rifle. Reliable at all ranges." },
		{ name = "MP5",           displayName = "MP5",           unlockLevel = 3,  unlockCost = 1,     robuxCost = 0, description = "Compact SMG. High fire rate, moderate damage." },
		{ name = "Shotgun",       displayName = "Shotgun",       unlockLevel = 5,  unlockCost = 1,     robuxCost = 0, description = "Devastating at close range. 10 pellets per shot." },
		{ name = "Sniper",        displayName = "Sniper Rifle",  unlockLevel = 8,  unlockCost = 9999,  robuxCost = 0, description = "Bolt-action. Massive damage with 12x scope." },
		{ name = "HyperlaserGun", displayName = "Hyperlaser",    unlockLevel = 12, unlockCost = 1,     robuxCost = 0, description = "Energy weapon. Zero spread, projectile-based." },
	},

	secondary = {
		{ name = "M9",       displayName = "M9",        unlockLevel = 0, unlockCost = 0, robuxCost = 0, description = "Standard sidearm. Reliable starter pistol." },
		{ name = "Glock17",  displayName = "Glock 17",  unlockLevel = 0, unlockCost = 1, robuxCost = 0, description = "Standard sidearm. Fast draw, reliable." },
		{ name = "Revolver", displayName = "Revolver",  unlockLevel = 6, unlockCost = 1, robuxCost = 0, description = "Heavy pistol. Slow fire, high damage." },
	},

	melee = {
		-- Add melee weapons here as they're created
	},
}
