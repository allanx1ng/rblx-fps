-- DataService bootstrap — auto-runs via Rojo like other .server.luau files.
--
-- Toggle options here for testing:
--   useMock = true         → uses mock ProfileStore (no real saves, safe for Studio)
--   resetData = true       → wipes all data on join (for fresh-start testing)
--   viewedUserId = 12345   → loads another player's data read-only
--   overridenUserId = 6789 → plays on another player's save
--   dontSave = true        → loads real data but skips saving on leave

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Shared.DataService).server
local DataTemplate = require(ReplicatedStorage.Shared.DataTemplate)

-- ---------------------------------------------------------------------------
-- Attribute bridge — syncs DataService values → player attributes so that
-- existing code reading attributes (ToolManager, Buffs, GUI controllers)
-- continues to work without modification.
-- ---------------------------------------------------------------------------
local function syncInitialAttributes(player, data)
	-- Simple scalar values
	player:SetAttribute("Gold", data.gold)
	player:SetAttribute("XP", data.xp)
	player:SetAttribute("Level", data.level)
	player:SetAttribute("XPForNextLevel", data.xpForNextLevel)

	-- Unlocks table → individual Unlocked_* attributes
	for name, value in data.unlocks do
		player:SetAttribute("Unlocked_" .. name, value)
	end

	-- Equipped table → individual Equipped_* attributes
	for slot, value in data.equipped do
		player:SetAttribute("Equipped_" .. slot, value)
	end
end

local function subscribeAttributeBridge(player)
	-- Scalar fields
	DataService:getChangedSignal(player, "gold"):Connect(function(newValue)
		player:SetAttribute("Gold", newValue)
	end)

	DataService:getChangedSignal(player, "xp"):Connect(function(newValue)
		player:SetAttribute("XP", newValue)
	end)

	DataService:getChangedSignal(player, "level"):Connect(function(newValue)
		player:SetAttribute("Level", newValue)
	end)

	DataService:getChangedSignal(player, "xpForNextLevel"):Connect(function(newValue)
		player:SetAttribute("XPForNextLevel", newValue)
	end)

	-- Unlocks — fires when any key in the unlocks table changes
	DataService:getIndexChangedSignal(player, "unlocks"):Connect(function(key, value)
		player:SetAttribute("Unlocked_" .. key, value)
	end)

	-- Equipped — fires when any key in the equipped table changes
	DataService:getIndexChangedSignal(player, "equipped"):Connect(function(key, value)
		player:SetAttribute("Equipped_" .. key, value)
	end)
end

-- ---------------------------------------------------------------------------
-- Override onPlayerInit to set up the bridge before data is available to
-- other scripts.
-- ---------------------------------------------------------------------------
function DataService:onPlayerInit(player, data)
	syncInitialAttributes(player, data)
	subscribeAttributeBridge(player)
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
DataService:init({
	template = DataTemplate,
	profileStoreIndex = "Testing",
	useMock = false, -- flip to false for real saves
	-- resetData = false,
	-- viewedUserId = 12345,
	-- overridenUserId = 6789,
	-- dontSave = true,
})
