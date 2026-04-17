-- Shared damage helpers used by Projectiles, Hitscan, and Melee handlers.

local DamageUtil = {}

-- Body part name -> torso flag (works for R6 and R15)
local TORSO_PARTS = {
	Torso = true,
	UpperTorso = true,
	LowerTorso = true,
	HumanoidRootPart = true,  -- often what raycasts actually hit
}

-- Returns the damage multiplier for a hit on the given body part.
-- config may define headshotMultiplier and limbMultiplier; torso is always 1x.
function DamageUtil.getMultiplier(partName, config)
	if partName == "Head" then
		return config.headshotMultiplier or 1
	elseif TORSO_PARTS[partName] then
		return 1
	else
		return config.limbMultiplier or 1
	end
end

return DamageUtil
