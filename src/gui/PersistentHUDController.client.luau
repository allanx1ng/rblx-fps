-- Always-visible HUD for resources and wave info (shared between lobby and in-game).
--
-- Lives at: StarterGui > PersistentHUD > PersistentHUDController (LocalScript)
--
-- Expected children (all optional, searched recursively):
--   Resources (Frame)
--     GoldIcon (Frame/ImageLabel)
--       GoldLabel (TextLabel)            — gold amount
--     XP (TextLabel)                     — level display ("Lv. 0")
--       Frame
--         XPFill  (Frame)               — progress bar fill (width scaled 0-1)
--         XPLabel (TextLabel)           — xp text ("50/100")
--   WaveStatus (TextLabel)              — wave info

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local persistentHUD = script.Parent

-- ---------------------------------------------------------------------------
-- Resolve GUI references (all optional)
-- ---------------------------------------------------------------------------
local goldLabel  = persistentHUD:FindFirstChild("GoldLabel", true)
local levelLabel = persistentHUD:FindFirstChild("XP", true)
local xpFill     = persistentHUD:FindFirstChild("XPFill", true)
local xpLabel    = persistentHUD:FindFirstChild("XPLabel", true)
local waveStatus = persistentHUD:FindFirstChild("WaveStatus", true)

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function formatNumber(n)
	local formatted = tostring(math.floor(n))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

local function updateGold()
	if not goldLabel then return end
	goldLabel.Text = formatNumber(player:GetAttribute("Gold") or 0)
end

local function updateXP()
	local xp = player:GetAttribute("XP") or 0
	local level = player:GetAttribute("Level") or 0
	local xpForNext = player:GetAttribute("XPForNextLevel") or 100

	if levelLabel then levelLabel.Text = "Lv. " .. level end
	if xpLabel then xpLabel.Text = formatNumber(xp) .. "/" .. formatNumber(xpForNext) end
	if xpFill then xpFill.Size = UDim2.new(math.clamp(xp / xpForNext, 0, 1), 0, 1, 0) end
end

local function updateWaveStatus()
	if not waveStatus then return end
	waveStatus.Text = player:GetAttribute("WaveStatus") or ""
end

-- ---------------------------------------------------------------------------
-- Initial draw + attribute listeners
-- ---------------------------------------------------------------------------
updateGold()
updateXP()
updateWaveStatus()

player.AttributeChanged:Connect(function(attr)
	if attr == "Gold" then
		updateGold()
	elseif attr == "XP" or attr == "Level" or attr == "XPForNextLevel" then
		updateXP()
	elseif attr == "WaveStatus" then
		updateWaveStatus()
	end
end)
