-- Dynamically populates weapon lists in the loadout UI from WeaponRegistry.
--
-- For each slot tab (primary, secondary), finds a ScrollingFrame/Frame
-- tagged "WeaponList_{slot}" and a template child tagged "WeaponListTemplate".
--
-- Clicking a weapon item populates the CurrWeapon panel (tagged "CurrWeapon")
-- inside the same loadout page. The EquipButton (tagged "EquipButton") inside
-- CurrWeapon toggles equip/unequip via the EquipWeapon RemoteEvent.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)

local lobbyUI = script:FindFirstAncestor("LobbyUI")
local EquipWeapon = ReplicatedStorage.Remotes.EquipWeapon

-- Per-slot state: which weapon is currently selected (viewed) in the UI
local selectedWeapon = {} -- [slot] = entry (from WeaponRegistry) or nil

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function findTaggedDescendant(ancestor, tag)
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(ancestor) then
			return instance
		end
	end
	return nil
end

local function isWeaponUnlocked(_entry)
	-- TODO: check player level and ownership when unlock system is implemented
	return true
end

local function isWeaponEquipped(entry, slot)
	local equipped = player:GetAttribute("Equipped_" .. slot)
	return equipped == entry.name
end

-- ---------------------------------------------------------------------------
-- CurrWeapon panel — one per slot page
-- ---------------------------------------------------------------------------
-- Maps slot -> { frame, nameLabel, descLabel, equipButton, connection }
local currWeaponPanels = {}

local function setupCurrWeaponPanel(slot)
	local pageTag = "LoadoutPage" .. slot:sub(1, 1):upper() .. slot:sub(2)
	local page
	for _, inst in CollectionService:GetTagged(pageTag) do
		if inst:IsDescendantOf(lobbyUI) then
			page = inst
			break
		end
	end
	if not page then return end

	local frame = findTaggedDescendant(page, "CurrWeapon")
	if not frame then return end

	local nameLabel = frame:FindFirstChild("WeaponName", true)
	local descLabel = frame:FindFirstChild("WeaponDesc", true)
	local equipButton = findTaggedDescendant(frame, "EquipButton")

	local panel = {
		frame = frame,
		nameLabel = nameLabel,
		descLabel = descLabel,
		equipButton = equipButton,
		buttonConn = nil, -- connection for equip button click
	}
	currWeaponPanels[slot] = panel
end

local function updateCurrWeaponPanel(slot)
	local panel = currWeaponPanels[slot]
	if not panel then return end

	local entry = selectedWeapon[slot]
	if not entry then
		panel.frame.Visible = false
		return
	end

	panel.frame.Visible = true

	if panel.nameLabel then
		panel.nameLabel.Text = entry.displayName
	end
	if panel.descLabel then
		panel.descLabel.Text = entry.description
	end

	-- Update equip button state
	if panel.equipButton then
		local equipped = isWeaponEquipped(entry, slot)
		panel.equipButton.Text = equipped and "Unequip" or "Equip"
	end

	-- Rewire button connection
	if panel.buttonConn then
		panel.buttonConn:Disconnect()
	end

	if panel.equipButton then
		panel.buttonConn = panel.equipButton.Activated:Connect(function()
			local equipped = isWeaponEquipped(entry, slot)
			if equipped then
				EquipWeapon:FireServer(slot, nil)
			else
				EquipWeapon:FireServer(slot, entry.name)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Weapon list building
-- ---------------------------------------------------------------------------
local function buildList(slot)
	local weapons = WeaponRegistry[slot]
	if not weapons or #weapons == 0 then return end

	local listFrame = findTaggedDescendant(lobbyUI, "WeaponList_" .. slot)
	if not listFrame then return end

	local template = findTaggedDescendant(listFrame, "WeaponListTemplate")
	if not template then return end

	template.Visible = false

	-- Clear previously generated items (but not the template)
	for _, child in listFrame:GetChildren() do
		if child ~= template and child:GetAttribute("Generated") then
			child:Destroy()
		end
	end

	for i, entry in weapons do
		local item = template:Clone()
		item.Name = entry.name
		item.LayoutOrder = i
		item:SetAttribute("Generated", true)
		item:SetAttribute("WeaponName", entry.name)
		item.Visible = true

		local nameLabel = item:FindFirstChild("WeaponName", true)
		if nameLabel then nameLabel.Text = entry.displayName end

		local equippedIcon = item:FindFirstChild("EquippedText", true)
		if equippedIcon then
			equippedIcon.Visible = isWeaponEquipped(entry, slot)
		end

		-- Wire the TextButton child for selection
		local button = item:FindFirstChildOfClass("TextButton") or item:FindFirstChildOfClass("ImageButton")
		if button then
			button.Activated:Connect(function()
				selectedWeapon[slot] = entry
				updateCurrWeaponPanel(slot)
			end)
		end

		item.Parent = listFrame
	end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
for _, slot in { "primary", "secondary" } do
	setupCurrWeaponPanel(slot)
	buildList(slot)
end

-- If the player already has weapons equipped (e.g. rejoining), select them in the UI
for _, slot in { "primary", "secondary" } do
	local equippedName = player:GetAttribute("Equipped_" .. slot)
	if equippedName then
		local weapons = WeaponRegistry[slot]
		if weapons then
			for _, entry in weapons do
				if entry.name == equippedName then
					selectedWeapon[slot] = entry
					break
				end
			end
		end
	end
	updateCurrWeaponPanel(slot)
end

-- Rebuild when player attributes change (equip change)
player.AttributeChanged:Connect(function(attr)
	if string.find(attr, "^Equipped_") then
		local slot = string.match(attr, "^Equipped_(.+)")
		if slot then
			buildList(slot)
			updateCurrWeaponPanel(slot)
		end
	end
end)
