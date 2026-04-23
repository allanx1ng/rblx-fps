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
-- If the weapon is locked, clicking the button opens the purchase popup instead.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)
local ItemRegistry = require(ReplicatedStorage.Shared.ItemRegistry)
local BuffRegistry = require(ReplicatedStorage.Shared.BuffRegistry)

local lobbyUI = script:FindFirstAncestor("LobbyUI")
local EquipWeapon = ReplicatedStorage.Remotes.EquipWeapon

-- Currency icon asset IDs
local COIN_ICON = "rbxassetid://93087943622513"
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"

-- Per-page state: which entry is currently selected (viewed) in the UI
-- For weapons: selectedEntry["primary"], selectedEntry["secondary"]
-- For items: selectedEntry["items"]
local selectedEntry = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- Uses GetDescendants + HasTag instead of GetTagged to avoid relying on
-- CollectionService's global index, which can lag behind after cloning.
local function findTaggedDescendant(ancestor, tag)
	for _, child in ancestor:GetDescendants() do
		if CollectionService:HasTag(child, tag) then
			return child
		end
	end
	return nil
end

local function isUnlocked(entry)
	return player:GetAttribute("Unlocked_" .. entry.name) == true
end

local function getEntryCost(entry)
	-- Returns cost, currencyType ("gold" | "robux"), icon
	if (entry.robuxCost or 0) > 0 then
		return entry.robuxCost, "robux", ROBUX_ICON
	end
	return entry.unlockCost or 0, "gold", COIN_ICON
end

-- ---------------------------------------------------------------------------
-- Item slot helpers
-- ---------------------------------------------------------------------------
local ITEM_SLOTS = { "item1", "item2" }
local BUFF_SLOTS = { "buff1", "buff2" }

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

-- Find which buff slot (if any) has this buff equipped
local function getBuffSlot(buffName)
	for _, slot in BUFF_SLOTS do
		if player:GetAttribute("Equipped_" .. slot) == buffName then
			return slot
		end
	end
	return nil
end

-- Find a free buff slot, or nil if both are full
local function getFreeBuffSlot()
	for _, slot in BUFF_SLOTS do
		if not player:GetAttribute("Equipped_" .. slot) then
			return slot
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- PriceDisplay helper — updates the PriceDisplay frame inside an EquipButton
-- ---------------------------------------------------------------------------
local function updatePriceDisplay(equipButton, entry)
	local priceDisplay = equipButton.Parent:FindFirstChild("PriceDisplay")
	if not priceDisplay then return end
	local equipLabel = equipButton:FindFirstChild("EquipLabel")
	local unlockLabel = equipButton:FindFirstChild("UnlockLabel")

	if isUnlocked(entry) then
		priceDisplay.Visible = false
		if unlockLabel then
			unlockLabel.Visible = false
		end

		if equipLabel then
			equipLabel.Visible = true
		end
		equipButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
		return
	end

	local cost, _, icon = getEntryCost(entry)
	priceDisplay.Visible = true
	equipButton.BackgroundColor3 = Color3.fromHex("00aaff")

	if unlockLabel then
		unlockLabel.Text = "Unlock"
		unlockLabel.Visible = true
	end
	if equipLabel then
			equipLabel.Visible = false
	end

	local currencyIcon = priceDisplay:FindFirstChild("CurrencyIcon")
	if currencyIcon then 
		currencyIcon.Image = icon
		currencyIcon.Size = UDim2.fromScale(0.4,0.4)
		currencyIcon.ScaleType = Enum.ScaleType.Crop
	end

	local priceAmount = priceDisplay:FindFirstChild("PriceAmount")
	if priceAmount then priceAmount.Text = tostring(cost) end
end

-- ---------------------------------------------------------------------------
-- Purchase popup trigger — fires a BindableEvent for the popup controller
-- ---------------------------------------------------------------------------
local function requestPurchase(entry)
	print("[WeaponListBuilder] requestPurchase called for:", entry.name)
	-- Wait for the BindableEvent created by PurchasePopupController
	local popupEvent = lobbyUI:WaitForChild("RequestPurchase", 5)
	if not popupEvent then
		warn("[WeaponListBuilder] RequestPurchase event not found")
		return
	end
	popupEvent:Fire(entry)
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

	local unlocked = isUnlocked(entry)
	local equipped = unlocked and player:GetAttribute("Equipped_" .. slot) == entry.name

	if panel.equipButton:FindFirstChild("EquipLabel") then
		if unlocked then
			panel.equipButton:FindFirstChild("EquipLabel").Text = equipped and "Unequip" or "Equip"
		else
			panel.equipButton:FindFirstChild("EquipLabel").Text = ""
		end
		updatePriceDisplay(panel.equipButton, entry)
	end

	if panel.buttonConn then panel.buttonConn:Disconnect() end

	if panel.equipButton then
		panel.buttonConn = panel.equipButton.Activated:Connect(function()
			print("[WeaponListBuilder] EquipButton clicked, entry:", entry.name, "unlocked:", isUnlocked(entry))
			if not isUnlocked(entry) then
				-- Weapon is locked — open purchase popup
				requestPurchase(entry)
				return
			end

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

	local unlocked = isUnlocked(entry)
	local equippedSlot = getItemSlot(entry.name)
	local buttonText
	local buttonAction

	if not unlocked then
		buttonText = ""
		buttonAction = function()
			requestPurchase(entry)
		end
	elseif equippedSlot then
		buttonText = "Unequip"
		buttonAction = function()
			EquipWeapon:FireServer(equippedSlot, nil)
		end
	else
		local freeSlot = getFreeItemSlot()
		if freeSlot then
			buttonText = "Equip"
			buttonAction = function()
				EquipWeapon:FireServer(freeSlot, entry.name)
			end
		else
			buttonText = "2 Items Max"
			buttonAction = nil
		end
	end

	if panel.equipButton then
		local equipLabel = panel.equipButton:FindFirstChild("EquipLabel")
		if equipLabel then
			if unlocked then
				equipLabel.Text = buttonText
				equipLabel.Visible = true
			else
				equipLabel.Visible = false
			end
		end
		updatePriceDisplay(panel.equipButton, entry)
	end

	if panel.buttonConn then panel.buttonConn:Disconnect() end

	if panel.equipButton and buttonAction then
		panel.buttonConn = panel.equipButton.Activated:Connect(buttonAction)
	end
end

-- ---------------------------------------------------------------------------
-- Cache list frames and templates once — no more tag lookups during rebuilds
-- ---------------------------------------------------------------------------
local cachedListFrames = {}  -- slot -> listFrame
local cachedTemplates = {}   -- slot -> template

local function cacheListData(slot)
	local listFrame = findTaggedDescendant(lobbyUI, "WeaponList_" .. slot)
	if not listFrame then return false end
	local template = findTaggedDescendant(listFrame, "WeaponListTemplate")
	if not template then return false end
	template.Visible = false
	cachedListFrames[slot] = listFrame
	cachedTemplates[slot] = template
	return true
end

-- ---------------------------------------------------------------------------
-- List building — weapons
-- ---------------------------------------------------------------------------
local function buildWeaponList(slot)
	local weapons = WeaponRegistry[slot]
	if not weapons or #weapons == 0 then return end

	local listFrame = cachedListFrames[slot]
	local template = cachedTemplates[slot]
	if not listFrame or not template then return end

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

		CollectionService:RemoveTag(item, "WeaponListTemplate")

		local nameLabel = item:FindFirstChild("WeaponName", true)
		if nameLabel then nameLabel.Text = entry.displayName end

		local unlocked = isUnlocked(entry)
		local equipped = unlocked and player:GetAttribute("Equipped_" .. slot) == entry.name

		local lockText = item:FindFirstChild("LockText", true)
		if lockText then
			if not unlocked then
				lockText.Text = "Locked"
				lockText.Visible = true
			elseif equipped then
				lockText.Visible = false
			else
				lockText.Text = ""
				lockText.Visible = true
			end
		end

		local equippedIcon = item:FindFirstChild("EquippedText", true)
		if equippedIcon then
			equippedIcon.Visible = equipped
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

	local listFrame = cachedListFrames["items"]
	local template = cachedTemplates["items"]
	if not listFrame or not template then return end

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

		CollectionService:RemoveTag(item, "WeaponListTemplate")

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
-- CurrWeapon panel update — buffs (passive)
-- ---------------------------------------------------------------------------
local function updateBuffPanel()
	local panel = currWeaponPanels["buffs"]
	if not panel then return end

	local entry = selectedEntry["buffs"]
	if not entry then
		panel.frame.Visible = false
		return
	end

	panel.frame.Visible = true

	if panel.nameLabel then panel.nameLabel.Text = entry.displayName end
	if panel.descLabel then panel.descLabel.Text = entry.description end

	local unlocked = isUnlocked(entry)
	local equippedSlot = getBuffSlot(entry.name)
	local buttonText
	local buttonAction

	if not unlocked then
		buttonText = ""
		buttonAction = function()
			requestPurchase(entry)
		end
	elseif equippedSlot then
		buttonText = "Unequip"
		buttonAction = function()
			EquipWeapon:FireServer(equippedSlot, nil)
		end
	else
		local freeSlot = getFreeBuffSlot()
		if freeSlot then
			buttonText = "Equip"
			buttonAction = function()
				EquipWeapon:FireServer(freeSlot, entry.name)
			end
		else
			buttonText = "2 Buffs Max"
			buttonAction = nil
		end
	end

	if panel.equipButton then
		local equipLabel = panel.equipButton:FindFirstChild("EquipLabel")
		if equipLabel then
			if unlocked then
				equipLabel.Text = buttonText
				equipLabel.Visible = true
			else
				equipLabel.Visible = false
			end
		else
			panel.equipButton.Text = buttonText
		end
		updatePriceDisplay(panel.equipButton, entry)
	end

	if panel.buttonConn then panel.buttonConn:Disconnect() end

	if panel.equipButton and buttonAction then
		panel.buttonConn = panel.equipButton.Activated:Connect(buttonAction)
	end
end

-- ---------------------------------------------------------------------------
-- List building — buffs (passive)
-- ---------------------------------------------------------------------------
local function buildBuffList()
	if #BuffRegistry == 0 then return end

	local listFrame = cachedListFrames["buffs"]
	local template = cachedTemplates["buffs"]
	if not listFrame or not template then return end

	for _, child in listFrame:GetChildren() do
		if child ~= template and child:GetAttribute("Generated") then
			child:Destroy()
		end
	end

	for i, entry in BuffRegistry do
		local item = template:Clone()
		item.Name = entry.name
		item.LayoutOrder = i
		item:SetAttribute("Generated", true)
		item:SetAttribute("WeaponName", entry.name)
		item.Visible = true

		CollectionService:RemoveTag(item, "WeaponListTemplate")

		local nameLabel = item:FindFirstChild("WeaponName", true)
		if nameLabel then nameLabel.Text = entry.displayName end

		local unlocked = isUnlocked(entry)

		local lockText = item:FindFirstChild("LockText", true)
		if lockText then lockText.Visible = not unlocked end

		local equippedIcon = item:FindFirstChild("EquippedText", true)
		if equippedIcon then
			equippedIcon.Visible = getBuffSlot(entry.name) ~= nil
		end

		local button = item:FindFirstChildOfClass("TextButton") or item:FindFirstChildOfClass("ImageButton")
		if button then
			button.Activated:Connect(function()
				selectedEntry["buffs"] = entry
				updateBuffPanel()
			end)
		end

		item.Parent = listFrame
	end
end

-- ---------------------------------------------------------------------------
-- Debounced rebuild — batches rapid attribute changes into a single rebuild
-- ---------------------------------------------------------------------------
local rebuildPending = false

local function scheduleRebuild()
	if rebuildPending then return end
	rebuildPending = true
	task.defer(function()
		rebuildPending = false
		for _, slot in { "primary", "secondary", "melee" } do
			buildWeaponList(slot)
			updateWeaponPanel(slot)
		end
		buildItemList()
		updateItemPanel()
		buildBuffList()
		updateBuffPanel()
	end)
end

-- ---------------------------------------------------------------------------
-- Init — synchronous, no retries needed (findTaggedDescendant uses HasTag)
-- ---------------------------------------------------------------------------
for _, slot in { "primary", "secondary", "melee" } do
	local pageTag = "LoadoutPage" .. slot:sub(1, 1):upper() .. slot:sub(2)
	setupCurrWeaponPanel(slot, pageTag)
	cacheListData(slot)
	buildWeaponList(slot)
end

setupCurrWeaponPanel("items", "LoadoutPageItems")
cacheListData("items")
buildItemList()

setupCurrWeaponPanel("buffs", "LoadoutPagePassives")
cacheListData("buffs")
buildBuffList()

-- Restore selection for already-equipped weapons
for _, slot in { "primary", "secondary", "melee" } do
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

-- Restore buff selection
for _, slot in BUFF_SLOTS do
	local equippedName = player:GetAttribute("Equipped_" .. slot)
	if equippedName then
		for _, entry in BuffRegistry do
			if entry.name == equippedName then
				selectedEntry["buffs"] = entry
				break
			end
		end
	end
end
updateBuffPanel()

-- Rebuild on attribute changes (equipped slots + unlock state)
player.AttributeChanged:Connect(function(attr)
	if string.find(attr, "^Unlocked_") then
		scheduleRebuild()
		return
	end

	if not string.find(attr, "^Equipped_") then return end

	local slot = string.match(attr, "^Equipped_(.+)")
	if not slot then return end

	if slot == "primary" or slot == "secondary" or slot == "melee" then
		buildWeaponList(slot)
		updateWeaponPanel(slot)
	elseif slot == "item1" or slot == "item2" then
		buildItemList()
		updateItemPanel()
	elseif slot == "buff1" or slot == "buff2" then
		buildBuffList()
		updateBuffPanel()
	end
end)
