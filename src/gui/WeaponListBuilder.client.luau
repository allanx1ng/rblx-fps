-- Dynamically populates weapon lists in the loadout UI from WeaponRegistry.
--
-- For each slot tab (primary, secondary, melee), finds a ScrollingFrame/Frame
-- tagged "WeaponList_{slot}" (e.g. "WeaponList_primary") and a template child
-- tagged "WeaponListTemplate" inside it.
--
-- The template is cloned for each weapon. Expected children in the template:
--   WeaponName   (TextLabel) — display name
--   WeaponDesc   (TextLabel) — description text
--   LockIcon     (any)       — shown when locked, hidden when unlocked
--   LockText     (TextLabel) — e.g. "Lv. 8 · 2,000g"
--   EquippedIcon (any)       — shown when currently equipped
--
-- All children are optional — missing ones are skipped.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)
local Guns = ReplicatedStorage.Shared.Guns

local lobbyUI = script:FindFirstAncestor("LobbyUI")

local function formatNumber(n)
	local formatted = tostring(math.floor(n))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

local function findTaggedDescendant(ancestor, tag)
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(ancestor) then
			return instance
		end
	end
	return nil
end

local function isWeaponUnlocked(entry)
	local level = player:GetAttribute("Level") or 1
	if level < entry.unlockLevel then return false end

	-- Check if purchased (for weapons that cost gold)
	if entry.unlockCost > 0 then
		local owned = player:GetAttribute("Owns_" .. entry.name)
		if not owned then return false end
	end

	return true
end

local function isWeaponEquipped(entry, slot)
	local equipped = player:GetAttribute("Equipped_" .. slot)
	return equipped == entry.name
end

local function buildList(slot)
	local weapons = WeaponRegistry[slot]
	if not weapons or #weapons == 0 then return end

	local listFrame = findTaggedDescendant(lobbyUI, "WeaponList_" .. slot)
	if not listFrame then return end

	local template = findTaggedDescendant(listFrame, "WeaponListTemplate")
	if not template then return end

	template.Visible = false

	-- Clear any previously generated items (but not the template)
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

		local descLabel = item:FindFirstChild("WeaponDesc", true)
		if descLabel then descLabel.Text = entry.description end

		local unlocked = isWeaponUnlocked(entry)

		local lockIcon = item:FindFirstChild("LockIcon", true)
		if lockIcon then lockIcon.Visible = not unlocked end

		local lockText = item:FindFirstChild("LockText", true)
		if lockText then
			if unlocked then
				lockText.Visible = false
			else
				lockText.Visible = true
				local parts = {}
				if entry.unlockLevel > 0 then
					table.insert(parts, "Lv. " .. entry.unlockLevel)
				end
				if entry.unlockCost > 0 then
					table.insert(parts, formatNumber(entry.unlockCost) .. "g")
				end
				lockText.Text = table.concat(parts, " · ")
			end
		end

		local equippedIcon = item:FindFirstChild("EquippedIcon", true)
		if equippedIcon then
			equippedIcon.Visible = isWeaponEquipped(entry, slot)
		end

		item.Parent = listFrame
	end
end

-- Build all slot lists
for _, slot in { "primary", "secondary", "melee" } do
	buildList(slot)
end

-- Rebuild when player attributes change (level up, purchase, equip change)
player.AttributeChanged:Connect(function(attr)
	if string.find(attr, "^Level") or string.find(attr, "^Owns_") or string.find(attr, "^Equipped_") then
		for _, slot in { "primary", "secondary", "melee" } do
			buildList(slot)
		end
	end
end)
