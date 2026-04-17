-- Defines display order and unlock requirements for active items.
-- This is the single source of truth for what appears in the items loadout UI.
--
-- Fields:
--   name         — must match the tool name in ServerStorage.WeaponTools
--                   AND the config module name in Items/Actives/
--   displayName  — shown in UI
--   unlockLevel  — minimum player level to use (0 = always available)
--   unlockCost   — gold cost to purchase (0 = free)
--   description  — short flavour text for the UI

return {
	{ name = "HealingPotion", displayName = "Healing Potion", unlockLevel = 0, unlockCost = 0, robuxCost = 0, description = "Instantly heal 50 HP. 10 second cooldown." },
	{ name = "SpeedPill",     displayName = "Speed Pill",     unlockLevel = 3, unlockCost = 300, robuxCost = 0, description = "Infinite stamina and +100% move speed for 20 seconds." },
}
