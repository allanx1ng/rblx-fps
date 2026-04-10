-- Drives the lobby HUD panel toggling and camera/cursor management.
--
-- Lives at: StarterGui > LobbyUI > HUD > HUDController (LocalScript)
--
-- Panel toggling from other scripts:
--   lobbyUI:WaitForChild("TogglePanel"):Fire("shop")
--   lobbyUI:WaitForChild("TogglePanel"):Fire("settings")
--   lobbyUI:WaitForChild("TogglePanel"):Fire("loadout")
--
-- Gold/XP/Level/Wave display has moved to PersistentHUD.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local hud = script.Parent
local lobbyUI = hud.Parent
lobbyUI.ResetOnSpawn = false
local main = lobbyUI:FindFirstChild("Main")

-- ---------------------------------------------------------------------------
-- Panel toggle state — only one panel open at a time
-- ---------------------------------------------------------------------------
local activePanel = nil  -- "shop" | "settings" | "loadout" | nil

local panels = {
	shop     = main and main:FindFirstChild("ShopPanel"),
	settings = main and main:FindFirstChild("SettingsPanel"),
	loadout  = main and main:FindFirstChild("LoadoutPanel"),
}

local function restoreCamera()
	if player:GetAttribute("InGame") then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		UserInputService.MouseIconEnabled = false
	else
		-- Lobby: third person, cursor visible
		player.CameraMode = Enum.CameraMode.Classic
		UserInputService.MouseIconEnabled = true
	end
end

local function togglePanel(panelName)
	if not panels[panelName] then return end

	if activePanel == panelName then
		panels[panelName].Visible = false
		activePanel = nil
		restoreCamera()
	else
		if activePanel and panels[activePanel] then
			panels[activePanel].Visible = false
		end
		panels[panelName].Visible = true
		activePanel = panelName
		UserInputService.MouseIconEnabled = true
		player.CameraMode = Enum.CameraMode.Classic
	end
	lobbyUI:SetAttribute("PanelOpen", activePanel ~= nil)
end

local function closeAllPanels()
	if activePanel then
		panels[activePanel].Visible = false
		activePanel = nil
		restoreCamera()
		lobbyUI:SetAttribute("PanelOpen", false)
	end
end

-- ---------------------------------------------------------------------------
-- BindableEvent — created FIRST so other scripts can WaitForChild immediately
-- Usage: lobbyUI:WaitForChild("TogglePanel"):Fire("shop")
-- ---------------------------------------------------------------------------
local toggleEvent = Instance.new("BindableEvent")
toggleEvent.Name = "TogglePanel"
toggleEvent.Parent = lobbyUI

toggleEvent.Event:Connect(function(panelName)
	if panelName == nil then
		closeAllPanels()
	elseif panels[panelName] then
		togglePanel(panelName)
	end
end)

-- ESC closes any open panel
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape then
		closeAllPanels()
	end
end)

-- ---------------------------------------------------------------------------
-- HUD buttons — optional, wired only if they exist
-- ---------------------------------------------------------------------------
local function wireButton(name, panelName)
	local button = hud:FindFirstChild(name, true)
	if button then
		button.Activated:Connect(function()
			togglePanel(panelName)
		end)
	end
end

wireButton("ShopButton", "shop")
wireButton("SettingsButton", "settings")
wireButton("LoadoutButton", "loadout")

-- ---------------------------------------------------------------------------
-- InGame state — toggle LobbyUI visibility and camera mode
-- ---------------------------------------------------------------------------
player.AttributeChanged:Connect(function(attr)
	if attr == "InGame" then
		local inGame = player:GetAttribute("InGame")
		local visible = not inGame
		lobbyUI.Enabled = visible
		-- Child ScreenGuis (e.g. HUD) have independent Enabled state
		for _, child in lobbyUI:GetDescendants() do
			if child:IsA("ScreenGui") then
				child.Enabled = visible
			end
		end
		closeAllPanels()
		restoreCamera()
	end
end)

player.CharacterAdded:Connect(function()
	restoreCamera()
end)

-- Set initial lobby state (camera + cursor)
restoreCamera()
