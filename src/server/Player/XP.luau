-- XP / Leveling system. Data is stored via DataService (persisted through ProfileStore).
-- Player attributes are kept in sync by the attribute bridge in DataInit.
--
-- External callers grant XP via:
--     local XP = require(ServerScriptService.Server.Player.XP)
--     XP.grantXP(player, amount)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelConfig = require(ReplicatedStorage.Shared.LevelConfig)
local DataService = require(ReplicatedStorage.Shared.DataService).server
local LevelUpRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LevelUp")

local XP = {}

local function resolveLevel(xp, level)
	while level < LevelConfig.maxLevel do
		local needed = LevelConfig.xpForLevel(level)
		if xp < needed then break end
		xp -= needed
		level += 1
	end
	if level >= LevelConfig.maxLevel then
		level = LevelConfig.maxLevel
		xp = 0
	end
	return xp, level
end

function XP.grantXP(player, amount)
	local oldLevel = DataService:get(player, "level") or LevelConfig.startLevel
	local xp = (DataService:get(player, "xp") or 0) + amount
	local level
	xp, level = resolveLevel(xp, oldLevel)

	DataService:set(player, "level", level)
	DataService:set(player, "xp", xp)
	DataService:set(player, "xpForNextLevel", LevelConfig.xpForLevel(level))

	if level > oldLevel then
		LevelUpRemote:FireClient(player, level)
	end
end

return XP
