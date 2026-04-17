-- XP / Leveling system. Owns the XP, Level, and XPForNextLevel attributes.
--
-- External callers grant XP via:
--     local XP = require(ServerScriptService.Server.Player.XP)
--     XP.grantXP(player, amount)
--
-- The "XP" attribute is also live-editable from Studio's properties panel —
-- the AttributeChanged hook resolves any level-ups automatically.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelConfig = require(ReplicatedStorage.Shared.LevelConfig)
local LevelUpRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LevelUp")

local XP = {}

local reconciling = {} -- [player] = true while we're writing back attributes

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

local function applyAttributes(player, xp, level)
	reconciling[player] = true
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", xp)
	player:SetAttribute("XPForNextLevel", LevelConfig.xpForLevel(level))
	reconciling[player] = nil
end

function XP.grantXP(player, amount)
	local oldLevel = player:GetAttribute("Level") or LevelConfig.startLevel
	local xp = (player:GetAttribute("XP") or 0) + amount
	local level
	xp, level = resolveLevel(xp, oldLevel)
	applyAttributes(player, xp, level)

	if level > oldLevel then
		LevelUpRemote:FireClient(player, level)
	end
end

local function onPlayerAdded(player)
	player:SetAttribute("Level", LevelConfig.startLevel)
	player:SetAttribute("XP", 0)
	player:SetAttribute("XPForNextLevel", LevelConfig.xpForLevel(LevelConfig.startLevel))

	-- Auto-level when XP is set manually (e.g. from Studio properties panel)
	player.AttributeChanged:Connect(function(attr)
		if attr == "XP" and not reconciling[player] then
			local xp = player:GetAttribute("XP") or 0
			local level = player:GetAttribute("Level") or LevelConfig.startLevel
			local needed = LevelConfig.xpForLevel(level)
			if xp >= needed then
				xp, level = resolveLevel(xp, level)
				applyAttributes(player, xp, level)
			end
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player)
	reconciling[player] = nil
end)

return XP
