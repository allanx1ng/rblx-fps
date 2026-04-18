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
--     ReloadText  (TextLabel)  -- shown while reloading or during item cooldown

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
	gunNameLabel = gunUI.Frame:WaitForChild("GunName")
	currentAmmoLabel = gunUI.Frame:WaitForChild("CurrentAmmo")
	spareAmmoLabel = gunUI.Frame:WaitForChild("SpareAmmo")
	reloadTextLabel = gunUI.Frame:WaitForChild("ReloadText")
end

fetchGui()

local activeConnections = {}
local cooldownHeartbeat = nil  -- Heartbeat connection for cooldown countdown

local function clearConnections()
	for _, conn in activeConnections do
		conn:Disconnect()
	end
	activeConnections = {}
	if cooldownHeartbeat then
		cooldownHeartbeat:Disconnect()
		cooldownHeartbeat = nil
	end
end

local function onToolEquipped(tool)
	if not player:GetAttribute("InGame") then
		gunUI.Enabled = false
		return
	end

	local ammoValue = tool:FindFirstChild("AmmoValue")
	local spareAmmoValue = tool:FindFirstChild("SpareAmmoValue")
	local capacityValue = tool:FindFirstChild("CapacityValue")
	local isReloadingValue = tool:FindFirstChild("IsReloadingValue")

	-- Item/non-gun tool detection
	local onCooldownValue = tool:FindFirstChild("OnCooldown")
	local cooldownEndValue = tool:FindFirstChild("CooldownEndTime")

	if not ammoValue or not spareAmmoValue or not capacityValue or not isReloadingValue then
		-- Not a gun (e.g. melee, item) — show name, no ammo tracking
		gunUI.Enabled = true
		gunNameLabel.Text = tool.Name

		-- Show uses count for consumable items, infinity for others
		local usesValue = tool:FindFirstChild("UsesValue")
		local maxUsesValue = tool:FindFirstChild("MaxUsesValue")
		if usesValue and maxUsesValue then
			currentAmmoLabel.Text = usesValue.Value .. "/" .. maxUsesValue.Value
			spareAmmoLabel.Text = ""
			table.insert(activeConnections, usesValue.Changed:Connect(function()
				currentAmmoLabel.Text = usesValue.Value .. "/" .. maxUsesValue.Value
			end))
		else
			currentAmmoLabel.Text = ""
			spareAmmoLabel.Text = "\u{221E}"
		end
		reloadTextLabel.Visible = false

		-- If this tool has cooldown support, wire up the countdown display
		if onCooldownValue and cooldownEndValue then
			local function updateCooldownDisplay()
				if onCooldownValue.Value then
					local remaining = cooldownEndValue.Value - tick()
					if remaining > 0 then
						reloadTextLabel.Text = string.format("Cooldown: %.1fs", remaining)
						reloadTextLabel.Visible = true

						-- Start per-frame countdown if not already running
						if not cooldownHeartbeat then
							cooldownHeartbeat = RunService.Heartbeat:Connect(function()
								if not onCooldownValue.Value then
									reloadTextLabel.Visible = false
									if cooldownHeartbeat then
										cooldownHeartbeat:Disconnect()
										cooldownHeartbeat = nil
									end
									return
								end
								local r = cooldownEndValue.Value - tick()
								if r > 0 then
									reloadTextLabel.Text = string.format("Cooldown: %.1fs", r)
								else
									reloadTextLabel.Visible = false
									if cooldownHeartbeat then
										cooldownHeartbeat:Disconnect()
										cooldownHeartbeat = nil
									end
								end
							end)
						end
					else
						reloadTextLabel.Visible = false
					end
				else
					reloadTextLabel.Visible = false
					if cooldownHeartbeat then
						cooldownHeartbeat:Disconnect()
						cooldownHeartbeat = nil
					end
				end
			end

			updateCooldownDisplay()
			table.insert(activeConnections, onCooldownValue.Changed:Connect(updateCooldownDisplay))
		end

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
		reloadTextLabel.Text = "Reloading"
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

-- Hide GunUI immediately when leaving game
player.AttributeChanged:Connect(function(attr)
	if attr == "InGame" and not player:GetAttribute("InGame") then
		clearConnections()
		if gunUI then gunUI.Enabled = false end
	end
end)

return {}
