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
--   WaveInfo (Frame)
--     WaveLabel (TextLabel)             — state label ("Intermission", "Wave 1")
--     WaveTimer (TextLabel)             — countdown ("0:25")

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
local waveLabel  = persistentHUD:FindFirstChild("WaveLabel", true)
local waveTimer  = persistentHUD:FindFirstChild("WaveTimer", true)

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

local function updateWaveLabel()
	if not waveLabel then return end
	waveLabel.Text = player:GetAttribute("WaveLabel") or ""
end

local function updateWaveTimer()
	if not waveTimer then return end
	waveTimer.Text = player:GetAttribute("WaveTimer") or ""
end

-- ---------------------------------------------------------------------------
-- Initial draw + attribute listeners
-- ---------------------------------------------------------------------------
updateGold()
updateXP()
updateWaveLabel()
updateWaveTimer()

player.AttributeChanged:Connect(function(attr)
	if attr == "Gold" then
		updateGold()
	elseif attr == "XP" or attr == "Level" or attr == "XPForNextLevel" then
		updateXP()
	elseif attr == "WaveLabel" then
		updateWaveLabel()
	elseif attr == "WaveTimer" then
		updateWaveTimer()
	end
end)
