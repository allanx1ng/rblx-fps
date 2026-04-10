-- Level progression config.
-- Adjust xpForLevel() to change scaling. Everything else reads from it.

local LevelConfig = {}

LevelConfig.maxLevel = 100
LevelConfig.startLevel = 0

-- XP required to advance FROM the given level to the next.
-- Currently flat 100 per level. To scale, change this function:
--   e.g. return 100 + level * 20   (120 for lv0→1, 140 for lv1→2, …)
--   e.g. return math.floor(100 * 1.1 ^ level)
function LevelConfig.xpForLevel(level: number): number
	return 100
end

return LevelConfig
