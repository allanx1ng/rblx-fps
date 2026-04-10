-- Server-authoritative game state management.
--
-- Owns the InGame attribute and controls the lobby ↔ game lifecycle:
--   • ProximityPrompt on "JoinGame" tagged parts triggers game entry
--   • Death while InGame sends the player back to the lobby
--   • Tools are granted on game entry and stripped on lobby return
--
-- Spawn points:
--   LobbySpawn  — SpawnLocation tagged "LobbySpawn" in Workspace
--   MapSpawn    — SpawnLocation named per MapConfig inside Workspace.Maps.{folder}

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.MapConfig)
local WeaponTools = ServerStorage:WaitForChild("WeaponTools")

local VALID_SLOTS = { "primary", "secondary", "item1", "item2" }

-- ---------------------------------------------------------------------------
-- Spawn point resolution
-- ---------------------------------------------------------------------------
local lobbySpawn -- resolved lazily so tagged parts have time to replicate

local function getLobbySpawn()
	if lobbySpawn then return lobbySpawn end
	local tagged = CollectionService:GetTagged("LobbySpawn")
	lobbySpawn = tagged[1]
	if not lobbySpawn then
		warn("[GameStateManager] No part tagged 'LobbySpawn' found — players will use default spawn")
	end
	return lobbySpawn
end

local function getMapSpawn(mapName)
	local config = MapConfig[mapName]
	if not config then
		warn("[GameStateManager] Unknown map:", mapName)
		return nil
	end
	local mapsFolder = workspace:FindFirstChild("Maps")
	if not mapsFolder then
		warn("[GameStateManager] Workspace.Maps folder not found")
		return nil
	end
	local mapFolder = mapsFolder:FindFirstChild(config.folder)
	if not mapFolder then
		warn("[GameStateManager] Map folder not found:", config.folder)
		return nil
	end
	local spawn = mapFolder:FindFirstChild(config.spawnPointName)
	if not spawn then
		warn("[GameStateManager] MapSpawn not found in", config.folder)
	end
	return spawn
end

-- ---------------------------------------------------------------------------
-- Tool management
-- ---------------------------------------------------------------------------
local function stripAllTools(player)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then child:Destroy() end
		end
	end
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then child:Destroy() end
		end
	end
end

local function grantEquippedTools(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	for _, slot in VALID_SLOTS do
		local toolName = player:GetAttribute("Equipped_" .. slot)
		if toolName then
			local template = WeaponTools:FindFirstChild(toolName)
			if template then
				local tool = template:Clone()
				tool:SetAttribute("Slot", slot)
				tool.Parent = backpack
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- State transitions
-- ---------------------------------------------------------------------------
local function sendToLobby(player)
	player:SetAttribute("InGame", false)
	player:SetAttribute("ActiveSlot", nil)
	stripAllTools(player)

	local spawn = getLobbySpawn()
	if spawn then
		player.RespawnLocation = spawn
	end
end

local function sendToGame(player, mapName)
	local character = player.Character
	if not character then return end
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local mapSpawn = getMapSpawn(mapName)
	if not mapSpawn then
		warn("[GameStateManager] Cannot enter game — map spawn missing for", mapName)
		return
	end

	-- Strip any stale tools from a previous session
	stripAllTools(player)

	player:SetAttribute("InGame", true)
	player:SetAttribute("ActiveSlot", nil)
	player.RespawnLocation = mapSpawn

	-- Grant fresh tools (full ammo — fresh clones from ServerStorage)
	grantEquippedTools(player)

	-- Teleport character to map spawn
	character:PivotTo(mapSpawn.CFrame + Vector3.new(0, 3, 0))
end

-- ---------------------------------------------------------------------------
-- ProximityPrompt — "JoinGame" tagged parts
-- ---------------------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local part = prompt.Parent
	if not part or not CollectionService:HasTag(part, "JoinGame") then return end
	if player:GetAttribute("InGame") then return end

	sendToGame(player, "Default")
end)

-- ---------------------------------------------------------------------------
-- Player setup + death handling
-- ---------------------------------------------------------------------------
local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		if player:GetAttribute("InGame") then
			sendToLobby(player)
		end
	end)
end

local function onPlayerAdded(player)
	player:SetAttribute("InGame", false)

	local spawn = getLobbySpawn()
	if spawn then
		player.RespawnLocation = spawn
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle players already in the game (e.g. late script start)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
