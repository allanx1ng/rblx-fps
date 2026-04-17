-- Defines display order, unlock requirements, and shop pricing for passive buffs.
-- This is the single source of truth for what appears in the buffs loadout UI
-- and what shop parts can sell.
--
-- Fields:
--   name         — must match the config module name in Buffs/
--   displayName  — shown in UI
--   unlockLevel  — minimum player level to use (0 = always available)
--   unlockCost   — gold cost to purchase (0 = free)
--   robuxCost    — Robux cost to purchase (0 = not a Robux item)
--   description  — short flavour text for the UI

return {
	{ name = "ExtraHealth1", displayName = "Extra Health I",  unlockLevel = 0, unlockCost = 200, robuxCost = 0, description = "+50 max HP while equipped (150 total)." },
	{ name = "ExtraHealth2", displayName = "Extra Health II", unlockLevel = 5, unlockCost = 500, robuxCost = 0, description = "+50 max HP while equipped (200 total with Extra Health I)." },
}
