-- Server-authoritative game state management + game loop.
--
-- Owns the InGame attribute and controls the lobby <-> game lifecycle:
--   * Game loop: Intermission -> Prep Time -> Wave -> repeat
--   * ProximityPrompt on "JoinGame" tagged parts only active during Prep Time
--   * Death while in-game during Wave: if all players dead, wave ends early
--   * Tools are granted on game entry and stripped on lobby return
--
-- Spawn points:
--   LobbySpawn  -- SpawnLocation tagged "LobbySpawn" in Workspace
--   MapSpawn    -- SpawnLocation named per MapConfig inside Workspace.Maps.{folder}
--
-- Player attributes set for HUD:
--   WaveLabel  -- "Intermission" / "Prep Time" / "Wave 1" / etc.
--   WaveTimer  -- "0:25" formatted countdown string

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")

local MapConfig = require(ReplicatedStorage.Shared.MapConfig)
local WaveSpawner = require(script.Parent:WaitForChild("Zombies"):WaitForChild("WaveSpawner"))
local ToolManager = require(script.Parent:WaitForChild("ToolManager"))
local Rewards = require(ServerScriptService.Server.Player.Rewards)

-- ---------------------------------------------------------------------------
-- Game loop constants
-- ---------------------------------------------------------------------------
local INTERMISSION_DURATION = 20
local PREP_DURATION = 20
local MAX_WAVE = 10
-- Optional hard timeout per wave (0 disables). When > 0, any wave that still
-- has zombies alive after WAVE_TIMEOUT seconds will force-clear and advance.
local WAVE_TIMEOUT = 0

local STATE_WAITING      = "Waiting"
local STATE_INTERMISSION = "Intermission"
local STATE_PREP         = "Prep Time"
local STATE_WAVE         = "Wave"

local gameLoopState      = STATE_WAITING
local currentLabelDisplay = ""
local currentTimerDisplay = ""

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

local stripAllTools = ToolManager.stripAllTools
local grantEquippedTools = ToolManager.grantEquippedTools

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
-- HUD attribute broadcasting
-- ---------------------------------------------------------------------------
local function formatTime(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function broadcastGameState()
	for _, p in Players:GetPlayers() do
		p:SetAttribute("WaveLabel", currentLabelDisplay)
		p:SetAttribute("WaveTimer", currentTimerDisplay)
	end
end

-- ---------------------------------------------------------------------------
-- ProximityPrompt control — only active during Prep Time
-- ---------------------------------------------------------------------------
local function setPromptsEnabled(enabled)
	for _, part in CollectionService:GetTagged("JoinGame") do
		for _, child in part:GetChildren() do
			if child:IsA("ProximityPrompt") then
				child.Enabled = enabled
			end
		end
	end
end

-- Handle JoinGame parts that stream in late
CollectionService:GetInstanceAddedSignal("JoinGame"):Connect(function(part)
	for _, child in part:GetChildren() do
		if child:IsA("ProximityPrompt") then
			child.Enabled = (gameLoopState == STATE_PREP)
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Player queries
-- ---------------------------------------------------------------------------
local function getAliveInGamePlayers()
	local result = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InGame") and not p:GetAttribute("_DiedInGame") then
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(result, p)
			end
		end
	end
	return result
end

local function getAliveLobbyPlayers()
	local result = {}
	for _, p in Players:GetPlayers() do
		if not p:GetAttribute("InGame") then
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(result, p)
			end
		end
	end
	return result
end

-- ---------------------------------------------------------------------------
-- ProximityPrompt — "JoinGame" tagged parts (only during Prep Time)
-- ---------------------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local part = prompt.Parent
	if not part or not CollectionService:HasTag(part, "JoinGame") then return end
	if player:GetAttribute("InGame") then return end
	if gameLoopState ~= STATE_PREP then return end

	sendToGame(player, "Default")
end)

-- ---------------------------------------------------------------------------
-- Game Loop
--   Intermission (30s, prompts off)
--     → auto-teleport alive lobby players into game
--   For wave in 1..MAX_WAVE:
--     Prep Time (20s, prompts on — late/respawned players can join)
--     Wave N (prompts off — spawn zombies, wait for clear or all-dead)
--   Outcomes:
--     Defeated (all players dead) → clean zombies, back to Intermission (wave resets)
--     Victory (wave MAX_WAVE cleared) → clean zombies, back to Intermission
--     Aborted (no players during prep) → silently back to Intermission
-- ---------------------------------------------------------------------------
local function sendAllInGamePlayersToLobby()
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InGame") then
			p:SetAttribute("_DiedInGame", nil)
			sendToLobby(p)

			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local spawn = getLobbySpawn()
				if spawn and char:FindFirstChild("HumanoidRootPart") then
					char:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
				end
			end
		end
	end
end

local function runGameLoop()
	while true do
		-- Wait for at least one player before starting
		while #Players:GetPlayers() == 0 do
			gameLoopState = STATE_WAITING
			currentLabelDisplay = ""
			currentTimerDisplay = ""
			task.wait(1)
		end

		-- ===================== INTERMISSION =====================
		gameLoopState = STATE_INTERMISSION
		setPromptsEnabled(false)
		currentLabelDisplay = "Intermission"

		for i = INTERMISSION_DURATION, 1, -1 do
			currentTimerDisplay = formatTime(i)
			broadcastGameState()
			task.wait(1)
		end
		currentTimerDisplay = "0:00"
		broadcastGameState()

		-- Auto-teleport all alive lobby players into the game
		for _, p in getAliveLobbyPlayers() do
			sendToGame(p, "Default")
		end

		-- ===================== WAVE LOOP ========================
		local defeated = false
		local aborted  = false

		for waveNumber = 1, MAX_WAVE do
			-- -------- Prep Time (also runs between waves) --------
			gameLoopState = STATE_PREP
			setPromptsEnabled(true)
			currentLabelDisplay = "Wave " .. waveNumber .. " in"

			for i = PREP_DURATION, 1, -1 do
				currentTimerDisplay = formatTime(i)
				broadcastGameState()
				task.wait(1)
			end
			currentTimerDisplay = "0:00"
			setPromptsEnabled(false)
			broadcastGameState()

			-- No players in game → abort the whole round
			if #getAliveInGamePlayers() == 0 then
				aborted = true
				break
			end

			-- -------- Wave --------
			gameLoopState = STATE_WAVE

			-- Snapshot players present at wave start (eligible for survival reward)
			local waveParticipants = {}
			for _, p in Players:GetPlayers() do
				if p:GetAttribute("InGame") then
					waveParticipants[p] = true
				end
			end

			WaveSpawner.startWave(waveNumber)
			local waveStartTime = tick()

			while true do
				currentLabelDisplay = "Wave " .. waveNumber
				currentTimerDisplay = WaveSpawner.getAliveCount() .. " left"
				broadcastGameState()

				task.wait(1)

				-- Wave cleared
				if WaveSpawner.areAllDead() then
					break
				end

				-- All players dead → defeat
				if #getAliveInGamePlayers() == 0 then
					defeated = true
					break
				end

				-- Optional hard timeout: force-clear and advance
				if WAVE_TIMEOUT > 0 and (tick() - waveStartTime) > WAVE_TIMEOUT then
					WaveSpawner.killAllZombies()
					break
				end
			end

			if defeated then break end

			-- Wave cleared — grant survival rewards to all wave participants
			for participant in waveParticipants do
				if participant.Parent then -- still connected
					Rewards.grantWaveSurvivalReward(participant)
				end
			end

			-- Wave cleared — brief pause showing the result
			currentLabelDisplay = "Wave " .. waveNumber .. " Cleared!"
			currentTimerDisplay = ""
			broadcastGameState()
			task.wait(2)
		end

		-- ===================== ROUND END =========================
		WaveSpawner.killAllZombies()

		if defeated then
			currentLabelDisplay = "Defeated!"
			currentTimerDisplay = ""
			broadcastGameState()
			task.wait(4)
		elseif not aborted then
			currentLabelDisplay = "Victory!"
			currentTimerDisplay = ""
			broadcastGameState()
			task.wait(4)
		end
		-- Aborted: skip the announcement and loop straight back to intermission

		-- Send any remaining in-game players back to lobby
		sendAllInGamePlayersToLobby()
	end
end

-- ---------------------------------------------------------------------------
-- Player setup + death handling
--
-- On death: keep InGame=true so the in-game HUD stays visible during the
-- death screen. Only set RespawnLocation to lobby so the respawn lands there.
-- On respawn (CharacterAdded): detect the pending lobby transition and apply it.
-- ---------------------------------------------------------------------------
local function onCharacterDied(player)
	if not player:GetAttribute("InGame") then return end

	-- Flag that we need to transition to lobby on respawn
	player:SetAttribute("_DiedInGame", true)

	-- Point respawn at lobby so Roblox spawns them there
	local spawn = getLobbySpawn()
	if spawn then
		player.RespawnLocation = spawn
	end
end

local function onCharacterAdded(player, character)
	-- Wire death handler
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		onCharacterDied(player)
	end)

	-- If this respawn follows a death-in-game, transition to lobby now
	if player:GetAttribute("_DiedInGame") then
		player:SetAttribute("_DiedInGame", nil)
		sendToLobby(player)
	end
end

local function onPlayerAdded(player)
	player:SetAttribute("InGame", false)

	-- Initialize wave display for this player
	player:SetAttribute("WaveLabel", currentLabelDisplay)
	player:SetAttribute("WaveTimer", currentTimerDisplay)

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

-- Start the game loop
task.spawn(runGameLoop)
