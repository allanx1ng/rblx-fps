-- Dynamically populates weapon/item lists in the loadout UI from registries.
--
-- For weapon slots (primary, secondary), finds a ScrollingFrame/Frame
-- tagged "WeaponList_{slot}" and a template child tagged "WeaponListTemplate".
--
-- For items, finds "WeaponList_items" with a "WeaponListTemplate" child.
-- Items can be equipped into item1 or item2 (max 2 items, no duplicates).
--
-- Clicking a list entry populates the CurrWeapon panel (tagged "CurrWeapon")
-- inside the same loadout page. The EquipButton (tagged "EquipButton") inside
-- CurrWeapon toggles equip/unequip via the EquipWeapon RemoteEvent.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)
local ItemRegistry = require(ReplicatedStorage.Shared.ItemRegistry)

local lobbyUI = script:FindFirstAncestor("LobbyUI")
local EquipWeapon = ReplicatedStorage.Remotes.EquipWeapon

-- Per-page state: which entry is currently selected (viewed) in the UI
-- For weapons: selectedEntry["primary"], selectedEntry["secondary"]
-- For items: selectedEntry["items"]
local selectedEntry = {}

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

local function isUnlocked(_entry)
	-- TODO: check player level and ownership when unlock system is implemented
	return true
end

-- ---------------------------------------------------------------------------
-- Item slot helpers
-- ---------------------------------------------------------------------------
local ITEM_SLOTS = { "item1", "item2" }

-- Find which item slot (if any) has this item equipped
local function getItemSlot(itemName)
	for _, slot in ITEM_SLOTS do
		if player:GetAttribute("Equipped_" .. slot) == itemName then
			return slot
		end
	end
	return nil
end

-- Find a free item slot, or nil if both are full
local function getFreeItemSlot()
	for _, slot in ITEM_SLOTS do
		if not player:GetAttribute("Equipped_" .. slot) then
			return slot
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- CurrWeapon panel setup
-- ---------------------------------------------------------------------------
-- Maps page key -> { frame, nameLabel, descLabel, equipButton, buttonConn }
-- Page keys: "primary", "secondary", "items"
local currWeaponPanels = {}

local function findPage(pageTag)
	for _, inst in CollectionService:GetTagged(pageTag) do
		if inst:IsDescendantOf(lobbyUI) then
			return inst
		end
	end
	return nil
end

local function setupCurrWeaponPanel(pageKey, pageTag)
	local page = findPage(pageTag)
	if not page then return end

	local frame = findTaggedDescendant(page, "CurrWeapon")
	if not frame then return end

	currWeaponPanels[pageKey] = {
		frame = frame,
		nameLabel = frame:FindFirstChild("WeaponName", true),
		descLabel = frame:FindFirstChild("WeaponDesc", true),
		equipButton = findTaggedDescendant(frame, "EquipButton"),
		buttonConn = nil,
	}
end

-- ---------------------------------------------------------------------------
-- CurrWeapon panel update — weapons (primary/secondary)
-- ---------------------------------------------------------------------------
local function updateWeaponPanel(slot)
	local panel = currWeaponPanels[slot]
	if not panel then return end

	local entry = selectedEntry[slot]
	if not entry then
		panel.frame.Visible = false
		return
	end

	panel.frame.Visible = true

	if panel.nameLabel then panel.nameLabel.Text = entry.displayName end
	if panel.descLabel then panel.descLabel.Text = entry.description end

	local equipped = player:GetAttribute("Equipped_" .. slot) == entry.name

	if panel.equipButton then
		panel.equipButton.Text = equipped and "Unequip" or "Equip"
	end

	if panel.buttonConn then panel.buttonConn:Disconnect() end

	if panel.equipButton then
		panel.buttonConn = panel.equipButton.Activated:Connect(function()
			if player:GetAttribute("Equipped_" .. slot) == entry.name then
				EquipWeapon:FireServer(slot, nil)
			else
				EquipWeapon:FireServer(slot, entry.name)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- CurrWeapon panel update — items
-- ---------------------------------------------------------------------------
local function updateItemPanel()
	local panel = currWeaponPanels["items"]
	if not panel then return end

	local entry = selectedEntry["items"]
	if not entry then
		panel.frame.Visible = false
		return
	end

	panel.frame.Visible = true

	if panel.nameLabel then panel.nameLabel.Text = entry.displayName end
	if panel.descLabel then panel.descLabel.Text = entry.description end

	-- Determine button state
	local equippedSlot = getItemSlot(entry.name)
	local buttonText
	local buttonAction

	if equippedSlot then
		-- Already equipped — offer unequip
		buttonText = "Unequip"
		buttonAction = function()
			EquipWeapon:FireServer(equippedSlot, nil)
		end
	else
		local freeSlot = getFreeItemSlot()
		if freeSlot then
			-- Free slot available — equip
			buttonText = "Equip"
			buttonAction = function()
				EquipWeapon:FireServer(freeSlot, entry.name)
			end
		else
			-- Both slots full
			buttonText = "2 Items Max"
			buttonAction = nil
		end
	end

	if panel.equipButton then
		panel.equipButton.Text = buttonText
	end

	if panel.buttonConn then panel.buttonConn:Disconnect() end

	if panel.equipButton and buttonAction then
		panel.buttonConn = panel.equipButton.Activated:Connect(buttonAction)
	end
end

-- ---------------------------------------------------------------------------
-- List building — weapons
-- ---------------------------------------------------------------------------
local function buildWeaponList(slot)
	local weapons = WeaponRegistry[slot]
	if not weapons or #weapons == 0 then return end

	local listFrame = findTaggedDescendant(lobbyUI, "WeaponList_" .. slot)
	if not listFrame then return end

	local template = findTaggedDescendant(listFrame, "WeaponListTemplate")
	if not template then return end

	template.Visible = false

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

		local unlocked = isUnlocked(entry)

		local lockText = item:FindFirstChild("LockText", true)
		if lockText then lockText.Visible = not unlocked end

		local equippedIcon = item:FindFirstChild("EquippedText", true)
		if equippedIcon then
			equippedIcon.Visible = player:GetAttribute("Equipped_" .. slot) == entry.name
		end

		local button = item:FindFirstChildOfClass("TextButton") or item:FindFirstChildOfClass("ImageButton")
		if button then
			button.Activated:Connect(function()
				selectedEntry[slot] = entry
				updateWeaponPanel(slot)
			end)
		end

		item.Parent = listFrame
	end
end

-- ---------------------------------------------------------------------------
-- List building — items
-- ---------------------------------------------------------------------------
local function buildItemList()
	if #ItemRegistry == 0 then return end

	local listFrame = findTaggedDescendant(lobbyUI, "WeaponList_items")
	if not listFrame then return end

	local template = findTaggedDescendant(listFrame, "WeaponListTemplate")
	if not template then return end

	template.Visible = false

	for _, child in listFrame:GetChildren() do
		if child ~= template and child:GetAttribute("Generated") then
			child:Destroy()
		end
	end

	for i, entry in ItemRegistry do
		local item = template:Clone()
		item.Name = entry.name
		item.LayoutOrder = i
		item:SetAttribute("Generated", true)
		item:SetAttribute("WeaponName", entry.name)
		item.Visible = true

		local nameLabel = item:FindFirstChild("WeaponName", true)
		if nameLabel then nameLabel.Text = entry.displayName end

		local unlocked = isUnlocked(entry)

		local lockText = item:FindFirstChild("LockText", true)
		if lockText then lockText.Visible = not unlocked end

		local equippedIcon = item:FindFirstChild("EquippedText", true)
		if equippedIcon then
			equippedIcon.Visible = getItemSlot(entry.name) ~= nil
		end

		local button = item:FindFirstChildOfClass("TextButton") or item:FindFirstChildOfClass("ImageButton")
		if button then
			button.Activated:Connect(function()
				selectedEntry["items"] = entry
				updateItemPanel()
			end)
		end

		item.Parent = listFrame
	end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
-- Weapon pages
for _, slot in { "primary", "secondary" } do
	local pageTag = "LoadoutPage" .. slot:sub(1, 1):upper() .. slot:sub(2)
	setupCurrWeaponPanel(slot, pageTag)
	buildWeaponList(slot)
end

-- Items page
setupCurrWeaponPanel("items", "LoadoutPageItems")
buildItemList()

-- Restore selection for already-equipped weapons/items on join
for _, slot in { "primary", "secondary" } do
	local equippedName = player:GetAttribute("Equipped_" .. slot)
	if equippedName then
		local weapons = WeaponRegistry[slot]
		if weapons then
			for _, entry in weapons do
				if entry.name == equippedName then
					selectedEntry[slot] = entry
					break
				end
			end
		end
	end
	updateWeaponPanel(slot)
end

-- Restore item selection
for _, slot in ITEM_SLOTS do
	local equippedName = player:GetAttribute("Equipped_" .. slot)
	if equippedName then
		for _, entry in ItemRegistry do
			if entry.name == equippedName then
				selectedEntry["items"] = entry
				break
			end
		end
	end
end
updateItemPanel()

-- Rebuild on attribute changes
player.AttributeChanged:Connect(function(attr)
	if not string.find(attr, "^Equipped_") then return end

	local slot = string.match(attr, "^Equipped_(.+)")
	if not slot then return end

	if slot == "primary" or slot == "secondary" then
		buildWeaponList(slot)
		updateWeaponPanel(slot)
	elseif slot == "item1" or slot == "item2" then
		buildItemList()
		updateItemPanel()
	end
end)
