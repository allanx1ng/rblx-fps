-- Inventory / loadout — server-authoritative slot management.
--
-- Slots: primary (1), secondary (2), melee (3), item1 (4), item2 (5)
-- Data is stored via DataService (persisted through ProfileStore).
-- Player attributes are kept in sync by the attribute bridge in DataInit.
--
-- Remotes handled here: SelectSlot, EquipWeapon, PurchaseWeapon

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)
local ItemRegistry = require(ReplicatedStorage.Shared.ItemRegistry)
local BuffRegistry = require(ReplicatedStorage.Shared.BuffRegistry)
local DataService = require(ReplicatedStorage.Shared.DataService).server
local ToolManager = require(script.Parent.Parent:WaitForChild("ToolManager"))

local VALID_SLOTS = {
	primary = true, secondary = true, melee = true,
	item1 = true, item2 = true,
	buff1 = true, buff2 = true,
}

-- ---------------------------------------------------------------------------
-- Registry lookups
-- ---------------------------------------------------------------------------
local freeUnlocks = {}
for _, weapons in WeaponRegistry do
	for _, entry in weapons do
		if (entry.unlockCost or 0) == 0 and (entry.robuxCost or 0) == 0 then
			freeUnlocks[entry.name] = true
		end
	end
end
for _, entry in ItemRegistry do
	if (entry.unlockCost or 0) == 0 and (entry.robuxCost or 0) == 0 then
		freeUnlocks[entry.name] = true
	end
end
for _, entry in BuffRegistry do
	if (entry.unlockCost or 0) == 0 and (entry.robuxCost or 0) == 0 then
		freeUnlocks[entry.name] = true
	end
end

local weaponSlotLookup = {}
for slot, weapons in WeaponRegistry do
	for _, entry in weapons do
		weaponSlotLookup[entry.name] = slot
	end
end

local VALID_ITEMS = {}
for _, entry in ItemRegistry do
	VALID_ITEMS[entry.name] = true
end

local VALID_BUFFS = {}
local buffEntryByName = {}
for _, entry in BuffRegistry do
	VALID_BUFFS[entry.name] = true
	buffEntryByName[entry.name] = entry
end

local findSlotTool = ToolManager.findSlotTool
local clearSlotTool = ToolManager.clearSlotTool
local grantTool = ToolManager.grantTool
local equipSlotTool = ToolManager.equipSlotTool
local regrantEquippedTools = ToolManager.grantEquippedTools

-- ---------------------------------------------------------------------------
-- Per-player init
-- ---------------------------------------------------------------------------
local function initPlayerUnlocks(player)
	for weaponName in freeUnlocks do
		if not DataService:get(player, { "unlocks", weaponName }) then
			DataService:set(player, { "unlocks", weaponName }, true)
		end
	end
end

local function onPlayerAdded(player)
	DataService:waitForData(player)

	initPlayerUnlocks(player)

	player.CharacterAdded:Connect(function(_character)
		task.defer(function()
			if player:GetAttribute("InGame") then
				regrantEquippedTools(player)
			end
		end)
	end)

	if player.Character then
		regrantEquippedTools(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

-- ---------------------------------------------------------------------------
-- SelectSlot — client presses 1-5, server equips the corresponding slot
-- ---------------------------------------------------------------------------
ReplicatedStorage.Remotes.SelectSlot.OnServerEvent:Connect(function(player, slot)
	if not VALID_SLOTS[slot] then return end
	if not player:GetAttribute("InGame") then return end

	local equippedName = DataService:get(player, { "equipped", slot })
	if not equippedName then return end

	local activeSlot = player:GetAttribute("ActiveSlot")
	if activeSlot == slot then return end

	player:SetAttribute("ActiveSlot", slot)
	equipSlotTool(player, slot)
end)

-- ---------------------------------------------------------------------------
-- EquipWeapon — loadout UI assigns a weapon/item to a slot
-- ---------------------------------------------------------------------------
local function isBuffSlot(slot)
	return slot == "buff1" or slot == "buff2"
end

local buffPrereqCache = {}
local function getBuffPrereq(buffName)
	if buffPrereqCache[buffName] ~= nil then
		return buffPrereqCache[buffName] or nil
	end
	local cfgModule = ReplicatedStorage.Shared:WaitForChild("Buffs"):FindFirstChild(buffName)
	local prereq = cfgModule and require(cfgModule).prerequisite or false
	buffPrereqCache[buffName] = prereq
	return prereq or nil
end

ReplicatedStorage.Remotes.EquipWeapon.OnServerEvent:Connect(function(player, slot, weaponName)
	if not VALID_SLOTS[slot] then return end
	if not DataService:hasProfile(player) then return end

	local inGame = player:GetAttribute("InGame")
	local wasActiveSlot = player:GetAttribute("ActiveSlot") == slot

	if inGame and not isBuffSlot(slot) then
		clearSlotTool(player, slot)
	end

	if weaponName == nil then
		DataService:set(player, { "equipped", slot }, nil)
		if wasActiveSlot then
			player:SetAttribute("ActiveSlot", nil)
		end
		return
	end

	if slot == "primary" or slot == "secondary" or slot == "melee" then
		if weaponSlotLookup[weaponName] ~= slot then return end
		if not DataService:get(player, { "unlocks", weaponName }) then return end
	elseif slot == "item1" or slot == "item2" then
		if not VALID_ITEMS[weaponName] then return end
		if not DataService:get(player, { "unlocks", weaponName }) then return end
	elseif isBuffSlot(slot) then
		if not VALID_BUFFS[weaponName] then return end
		if not DataService:get(player, { "unlocks", weaponName }) then return end
		for _, otherSlot in { "buff1", "buff2" } do
			if otherSlot ~= slot and DataService:get(player, { "equipped", otherSlot }) == weaponName then
				return
			end
		end
		local prereq = getBuffPrereq(weaponName)
		if prereq and not DataService:get(player, { "unlocks", prereq }) then return end
	end

	DataService:set(player, { "equipped", slot }, weaponName)

	if inGame and not isBuffSlot(slot) then
		grantTool(player, weaponName, slot)
		if wasActiveSlot then
			equipSlotTool(player, slot)
		end
	end
end)

-- ---------------------------------------------------------------------------
-- PurchaseWeapon — client requests to buy a weapon with gold
-- ---------------------------------------------------------------------------
ReplicatedStorage.Remotes.PurchaseWeapon.OnServerEvent:Connect(function(player, weaponName)
	if not weaponName or type(weaponName) ~= "string" then return end
	if not DataService:hasProfile(player) then return end

	if DataService:get(player, { "unlocks", weaponName }) then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Already unlocked!",
		})
		return
	end

	local entry = nil
	for _, weapons in WeaponRegistry do
		for _, w in weapons do
			if w.name == weaponName then
				entry = w
				break
			end
		end
		if entry then break end
	end
	if not entry then
		for _, item in ItemRegistry do
			if item.name == weaponName then entry = item break end
		end
	end
	if not entry then
		for _, buff in BuffRegistry do
			if buff.name == weaponName then entry = buff break end
		end
	end

	if not entry then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Invalid weapon.",
		})
		return
	end

	if (entry.robuxCost or 0) > 0 then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Robux purchases are not available yet.",
		})
		return
	end

	local cost = entry.unlockCost or 0
	local gold = DataService:get(player, "gold") or 0

	if gold < cost then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Not enough gold!",
		})
		return
	end

	DataService:set(player, "gold", gold - cost)
	DataService:set(player, { "unlocks", weaponName }, true)

	ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
		success = true,
		message = "Purchased!",
		weaponName = weaponName,
	})
end)
