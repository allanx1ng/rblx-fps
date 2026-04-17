-- Rewards module — grants gold and XP for kills and wave survival.
--
-- Public API:
--   Rewards.grantKillReward(player)           -- 10 gold + 10 XP
--   Rewards.grantWaveSurvivalReward(player)   -- 50 gold + 50 XP

local ServerScriptService = game:GetService("ServerScriptService")

local XP = require(ServerScriptService.Server.Player.XP)

local Rewards = {}

local KILL_GOLD = 10
local KILL_XP   = 10

local WAVE_GOLD = 50
local WAVE_XP   = 50

local function grantGold(player, amount)
	local current = player:GetAttribute("Gold") or 0
	player:SetAttribute("Gold", current + amount)
end

function Rewards.grantKillReward(player)
	grantGold(player, KILL_GOLD)
	XP.grantXP(player, KILL_XP)
end

function Rewards.grantWaveSurvivalReward(player)
	grantGold(player, WAVE_GOLD)
	XP.grantXP(player, WAVE_XP)
end

return Rewards
