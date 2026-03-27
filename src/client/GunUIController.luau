-- Updates the GunUI ScreenGui based on the equipped gun's ammo counts.
--
-- GunHandler (tool VM) writes ammo state to IntValues inside the Tool.
-- This script (StarterPlayerScripts VM) reads them via Changed events —
-- the same cross-VM IPC pattern used by CrosshairController for SpreadValue.
--
-- Expected GunUI structure in StarterGui:
--   GunUI (ScreenGui)
--     GunName     (TextLabel)
--     CurrentAmmo (TextLabel)  -- displays "12/30"
--     SpareAmmo   (TextLabel)  -- displays "60"
--     ReloadText  (TextLabel)  -- shown only while reloading

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Mutable GUI references — refreshed on every respawn
local gunUI
local gunNameLabel
local currentAmmoLabel
local spareAmmoLabel
local reloadTextLabel

local function fetchGui()
	gunUI = playerGui:WaitForChild("GunUI")
	gunNameLabel = gunUI:WaitForChild("GunName")
	currentAmmoLabel = gunUI:WaitForChild("CurrentAmmo")
	spareAmmoLabel = gunUI:WaitForChild("SpareAmmo")
	reloadTextLabel = gunUI:WaitForChild("ReloadText")
end

fetchGui()

local activeConnections = {}

local function clearConnections()
	for _, conn in activeConnections do
		conn:Disconnect()
	end
	activeConnections = {}
end

local function onToolEquipped(tool)
	local ammoValue = tool:FindFirstChild("AmmoValue")
	local spareAmmoValue = tool:FindFirstChild("SpareAmmoValue")
	local capacityValue = tool:FindFirstChild("CapacityValue")
	local isReloadingValue = tool:FindFirstChild("IsReloadingValue")

	if not ammoValue or not spareAmmoValue or not capacityValue or not isReloadingValue then
		-- Not a gun with ammo tracking — hide the UI
		gunUI.Enabled = false
		return
	end

	gunUI.Enabled = true
	gunNameLabel.Text = tool.Name

	local function updateCurrentAmmo()
		currentAmmoLabel.Text = ammoValue.Value .. "/" .. capacityValue.Value
	end

	local function updateSpareAmmo()
		spareAmmoLabel.Text = tostring(spareAmmoValue.Value)
	end

	local function updateReloading()
		reloadTextLabel.Visible = isReloadingValue.Value
	end

	updateCurrentAmmo()
	updateSpareAmmo()
	updateReloading()

	table.insert(activeConnections, ammoValue.Changed:Connect(updateCurrentAmmo))
	table.insert(activeConnections, spareAmmoValue.Changed:Connect(updateSpareAmmo))
	table.insert(activeConnections, isReloadingValue.Changed:Connect(updateReloading))
end

local function watchCharacter(character)
	clearConnections()
	gunUI.Enabled = false

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			clearConnections()
			onToolEquipped(child)
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			clearConnections()
			gunUI.Enabled = false
		end
	end)

	-- Already holding a tool when character spawns
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		onToolEquipped(tool)
	end
end

-- Re-fetch GUI references after every respawn, then watch the new character.
player.CharacterAdded:Connect(function(character)
	fetchGui()
	watchCharacter(character)
end)

if player.Character then
	watchCharacter(player.Character)
end

return {}
