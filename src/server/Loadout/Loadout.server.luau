-- Inventory / loadout — server-authoritative slot management.
--
-- Slots: primary (1), secondary (2), melee (3), item1 (4), item2 (5)
-- Player attributes:
--   Equipped_<slot>     = weapon/item name selected for that slot
--   ActiveSlot          = slot currently held in-hand
--   Unlocked_<weapon>   = true when the player owns the weapon
--   Gold                = currency for weapon purchases
--   InGame              = true while in a wave run; tools only granted then
--
-- Remotes handled here: SelectSlot, EquipWeapon, PurchaseWeapon
--
-- Default loadout (set on join): secondary=M9, melee=Knife.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)
local ItemRegistry = require(ReplicatedStorage.Shared.ItemRegistry)
local BuffRegistry = require(ReplicatedStorage.Shared.BuffRegistry)
local ToolManager = require(script.Parent.Parent:WaitForChild("ToolManager"))

local DEFAULT_GOLD = 999
local VALID_SLOTS = {
	primary = true, secondary = true, melee = true,
	item1 = true, item2 = true,
	buff1 = true, buff2 = true,
}

-- ---------------------------------------------------------------------------
-- Registry lookups
-- ---------------------------------------------------------------------------
-- Free unlockables (auto-granted on join). Anything in WeaponRegistry,
-- ItemRegistry, or BuffRegistry with both costs zero is free.
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

-- weaponName -> slot, for validating EquipWeapon requests
local weaponSlotLookup = {}
for slot, weapons in WeaponRegistry do
	for _, entry in weapons do
		weaponSlotLookup[entry.name] = slot
	end
end

-- Set of valid item names (for item1/item2 slots)
local VALID_ITEMS = {}
for _, entry in ItemRegistry do
	VALID_ITEMS[entry.name] = true
end

-- Set of valid buff names + lookup by name (for buff1/buff2 slots)
local VALID_BUFFS = {}
local buffEntryByName = {}
for _, entry in BuffRegistry do
	VALID_BUFFS[entry.name] = true
	buffEntryByName[entry.name] = entry
end

-- Tool helpers — delegated to the shared ToolManager module
local findSlotTool = ToolManager.findSlotTool
local clearSlotTool = ToolManager.clearSlotTool
local grantTool = ToolManager.grantTool
local equipSlotTool = ToolManager.equipSlotTool
local regrantEquippedTools = ToolManager.grantEquippedTools

-- ---------------------------------------------------------------------------
-- Per-player init
-- ---------------------------------------------------------------------------
local function initPlayerUnlocks(player)
	-- TODO: Load persisted unlocks from DataStore and apply here.
	for weaponName in freeUnlocks do
		player:SetAttribute("Unlocked_" .. weaponName, true)
	end
end

local function onPlayerAdded(player)
	player:SetAttribute("Gold", DEFAULT_GOLD)
	initPlayerUnlocks(player)

	-- Auto-equip starter weapons if nothing equipped yet
	if not player:GetAttribute("Equipped_secondary") then
		player:SetAttribute("Equipped_secondary", "M9")
	end
	if not player:GetAttribute("Equipped_melee") then
		player:SetAttribute("Equipped_melee", "Knife")
	end
	if not player:GetAttribute("Equipped_item1") then
		player:SetAttribute("Equipped_item1", "HealingPotion")
	end

	player.CharacterAdded:Connect(function(_character)
		-- Defer regrant so GameStateManager's CharacterAdded handler runs first
		-- (it clears InGame on death-respawn before we check it here).
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
	onPlayerAdded(p)
end

-- ---------------------------------------------------------------------------
-- SelectSlot — client presses 1-5, server equips the corresponding slot
-- ---------------------------------------------------------------------------
ReplicatedStorage.Remotes.SelectSlot.OnServerEvent:Connect(function(player, slot)
	print("[SelectSlot] slot:", slot, "valid:", VALID_SLOTS[slot], "inGame:", player:GetAttribute("InGame"))
	if not VALID_SLOTS[slot] then return end
	if not player:GetAttribute("InGame") then return end

	local equippedName = player:GetAttribute("Equipped_" .. slot)
	print("[SelectSlot] equippedName:", equippedName)
	if not equippedName then return end

	local activeSlot = player:GetAttribute("ActiveSlot")
	print("[SelectSlot] activeSlot:", activeSlot, "requested:", slot)
	if activeSlot == slot then return end

	player:SetAttribute("ActiveSlot", slot)
	local tool = findSlotTool(player, slot)
	print("[SelectSlot] findSlotTool result:", tool, tool and tool.Name or "nil")
	equipSlotTool(player, slot)
end)

-- ---------------------------------------------------------------------------
-- EquipWeapon — loadout UI assigns a weapon/item to a slot
-- ---------------------------------------------------------------------------
local function isBuffSlot(slot)
	return slot == "buff1" or slot == "buff2"
end

-- Cached buff prerequisite lookup (loaded once per buff name)
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

	local inGame = player:GetAttribute("InGame")
	local wasActiveSlot = player:GetAttribute("ActiveSlot") == slot

	-- Buff slots are pure attribute storage — no Tool to clear/grant.
	if inGame and not isBuffSlot(slot) then
		clearSlotTool(player, slot)
	end

	if weaponName == nil then
		player:SetAttribute("Equipped_" .. slot, nil)
		if wasActiveSlot then
			player:SetAttribute("ActiveSlot", nil)
		end
		return
	end

	if slot == "primary" or slot == "secondary" or slot == "melee" then
		if weaponSlotLookup[weaponName] ~= slot then return end
		if not player:GetAttribute("Unlocked_" .. weaponName) then return end
	elseif slot == "item1" or slot == "item2" then
		if not VALID_ITEMS[weaponName] then return end
		if not player:GetAttribute("Unlocked_" .. weaponName) then return end
	elseif isBuffSlot(slot) then
		if not VALID_BUFFS[weaponName] then return end
		if not player:GetAttribute("Unlocked_" .. weaponName) then return end
		-- A buff can only occupy one slot at a time
		for _, otherSlot in { "buff1", "buff2" } do
			if otherSlot ~= slot and player:GetAttribute("Equipped_" .. otherSlot) == weaponName then
				return
			end
		end
		local prereq = getBuffPrereq(weaponName)
		if prereq and not player:GetAttribute("Unlocked_" .. prereq) then return end
	end

	player:SetAttribute("Equipped_" .. slot, weaponName)

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

	if player:GetAttribute("Unlocked_" .. weaponName) then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Already unlocked!",
		})
		return
	end

	-- Search WeaponRegistry, ItemRegistry, and BuffRegistry — purchase flow is
	-- generic across all unlockables.
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

	-- Robux purchases not handled here yet (use MarketplaceService in the future)
	if (entry.robuxCost or 0) > 0 then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Robux purchases are not available yet.",
		})
		return
	end

	local cost = entry.unlockCost or 0
	local gold = player:GetAttribute("Gold") or 0

	if gold < cost then
		ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
			success = false,
			message = "Not enough gold!",
		})
		return
	end

	player:SetAttribute("Gold", gold - cost)
	player:SetAttribute("Unlocked_" .. weaponName, true)

	-- TODO: Persist unlock to DataStore here.

	ReplicatedStorage.Remotes.PurchaseWeapon:FireClient(player, {
		success = true,
		message = "Purchased!",
		weaponName = weaponName,
	})
end)
