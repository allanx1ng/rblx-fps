-- Server bootstrap.
--
-- Most server logic lives in sibling scripts that auto-run:
--   DataInit                — DataService bootstrap + attribute bridge
--   CollisionGroups         — physics group setup + barrier tagging
--   Combat/Projectiles      — FireProjectile remote
--   Combat/Hitscan          — DealDamage remote
--   Combat/Melee            — MeleeSwing / MeleeDamage remotes
--   Items/HealingPotion     — UseHealingPotion remote
--   Loadout/Loadout         — slot management, EquipWeapon, PurchaseWeapon
--   Player/HealthRegen      — custom regen replacing Roblox default
--   GameStateManager        — wave loop, InGame transitions
--   ShopParts               — shop interaction parts
--   ThirdPersonPose         — third-person animation rig
--   Zombies/*               — zombie/wave logic
--
-- This script handles only what doesn't fit any of those: HUD attribute
-- defaults and pre-loading the XP module so it's available for require.

local Players = game:GetService("Players")

-- Pre-load the XP module so other server scripts can require it.
require(script:WaitForChild("Player"):WaitForChild("XP"))

local function onPlayerAdded(player)
	-- Game state — owned by GameStateManager but defaulted here so a brand-new
	-- player joining mid-intermission has sane attribute values immediately.
	player:SetAttribute("InGame", false)
	if not player:GetAttribute("WaveLabel") then
		player:SetAttribute("WaveLabel", "")
	end
	if not player:GetAttribute("WaveTimer") then
		player:SetAttribute("WaveTimer", "")
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end
