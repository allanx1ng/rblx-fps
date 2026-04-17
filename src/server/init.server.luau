-- Server bootstrap.
--
-- Most server logic lives in sibling scripts that auto-run:
--   CollisionGroups          — physics group setup + barrier tagging
--   Combat/Projectiles       — FireProjectile remote
--   Combat/Hitscan           — DealDamage remote
--   Combat/Melee             — MeleeSwing / MeleeDamage remotes
--   Items/HealingPotion      — UseHealingPotion remote
--   Loadout/Loadout          — slot management, EquipWeapon, PurchaseWeapon
--   Player/HealthRegen       — custom regen replacing Roblox default
--   GameStateManager         — wave loop, InGame transitions
--   ShopParts                — shop interaction parts
--   ThirdPersonPose          — third-person animation rig
--   Zombies/*                — zombie/wave logic
--
-- This script handles only what doesn't fit any of those: HUD attribute
-- defaults and bootstrapping the XP ModuleScript.

local Players = game:GetService("Players")

-- Booting the XP ModuleScript registers its PlayerAdded listener and exposes
-- grantXP(player, amount) for any other server script to require.
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
