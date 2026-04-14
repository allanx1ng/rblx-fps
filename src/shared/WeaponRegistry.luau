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
		{ name = "M4",            displayName = "M4 Carbine",     unlockLevel = 0,  unlockCost = 1,     robuxCost = 0, description = "Full-auto assault rifle. Reliable at all ranges." },
		{ name = "MP5",           displayName = "MP5",            unlockLevel = 3,  unlockCost = 1,     robuxCost = 0, description = "Compact SMG. High fire rate, moderate damage." },
		{ name = "Uzi",           displayName = "Uzi",            unlockLevel = 4,  unlockCost = 1,     robuxCost = 0, description = "Blazing fire rate SMG. Spray and pray." },
		{ name = "Shotgun",       displayName = "Shotgun",        unlockLevel = 5,  unlockCost = 1,     robuxCost = 0, description = "Devastating at close range. 10 pellets per shot." },
		{ name = "AK47",          displayName = "AK-47",          unlockLevel = 7,  unlockCost = 1,     robuxCost = 0, description = "Heavy assault rifle. High damage, strong recoil." },
		{ name = "Sniper",        displayName = "Sniper Rifle",   unlockLevel = 8,  unlockCost = 995,  robuxCost = 0, description = "Bolt-action. Massive damage with 12x scope." },
		{ name = "DMR",           displayName = "DMR",            unlockLevel = 10, unlockCost = 0,     robuxCost = 500, description = "Semi-auto marksman rifle. Precise and deadly." },
		{ name = "HuntingRifle",  displayName = "Hunting Rifle",  unlockLevel = 12, unlockCost = 1,     robuxCost = 0, description = "Lever-action rifle. High damage, slow fire." },
		{ name = "M249",          displayName = "M249",           unlockLevel = 15, unlockCost = 1,     robuxCost = 0, description = "Belt-fed machine gun. 100 rounds of suppression." },
		{ name = "Minigun",       displayName = "Minigun",        unlockLevel = 20, unlockCost = 1,     robuxCost = 0, description = "Rotary cannon. Insane fire rate, huge mag." },
		{ name = "RPG",           displayName = "RPG",            unlockLevel = 10, unlockCost = 1,     robuxCost = 0, description = "Rocket launcher. Explosive area damage." },
	},

	secondary = {
		{ name = "M9",             displayName = "M9",             unlockLevel = 0,  unlockCost = 0, robuxCost = 0, description = "Standard sidearm. Reliable starter pistol." },
		{ name = "Glock17",        displayName = "Glock 17",       unlockLevel = 0,  unlockCost = 1, robuxCost = 0, description = "Standard sidearm. Fast draw, reliable." },
		{ name = "Deagle",         displayName = "Desert Eagle",   unlockLevel = 5,  unlockCost = 1, robuxCost = 0, description = "Hand cannon. Slow fire, devastating damage." },
		{ name = "Revolver",       displayName = "Revolver",       unlockLevel = 6,  unlockCost = 1, robuxCost = 0, description = "Heavy pistol. Slow fire, high damage." },
		{ name = "Shorty",         displayName = "Shorty",         unlockLevel = 8,  unlockCost = 1, robuxCost = 0, description = "Sawed-off shotgun. Two shots of close-range fury." },
		{ name = "HyperlaserGun",  displayName = "Hyperlaser",     unlockLevel = 12, unlockCost = 1, robuxCost = 0, description = "Energy weapon. Zero spread, projectile-based." },
	},

	melee = {
		{ name = "Knife", displayName = "Knife", unlockLevel = 0, unlockCost = 0, robuxCost = 0, description = "Fast combat knife. Quick slashes, always ready." },
		{ name = "Sword", displayName = "Sword", unlockLevel = 3, unlockCost = 1, robuxCost = 0, description = "Heavy blade. Slower swing, higher damage." },
	},
}
