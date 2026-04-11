-- Wave spawning module — called from GameStateManager.
--
-- Multiple parts tagged "ZombieSpawn" act as a shared pool of spawn points;
-- each spawned zombie picks a random point from the pool.
--
-- Public API:
--   WaveSpawner.startWave(waveNumber)   -- spawn a wave's worth of zombies
--   WaveSpawner.getAliveCount()         -- count still-alive tracked zombies
--   WaveSpawner.areAllDead()            -- true when no tracked zombies remain
--   WaveSpawner.killAllZombies()        -- destroy every tracked zombie
--   WaveSpawner.getSpawnPoints()        -- debug: list tagged spawners
--
-- Only zombies spawned by this module are tracked — TestSpawner zombies or
-- anything else tagged "Enemy_Zombie" are left alone.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local WaveSpawner = {}

-- ---------------------------------------------------------------------------
-- Tuning (keep behavior identical to the old standalone spawner)
-- ---------------------------------------------------------------------------
local BASE_ZOMBIE_COUNT = 3
local COUNT_INCREMENT = 2

local BASE_HEALTH = 100
local BASE_DAMAGE = 10
local BASE_WALK_SPEED = 16

local HEALTH_PER_WAVE = 15
local DAMAGE_PER_WAVE = 2
local SPEED_PER_WAVE = 0.3

local ZOMBIE_TYPES = {
	{ name = "Normal",  model = "NormalZombie",  baseWeight = 50, weightDecay = -3, minWeight = 10, speedMult = 1.0 },
	{ name = "Runner",  model = "RunnerZombie",  baseWeight = 30, weightDecay = -1, minWeight = 10, speedMult = 1.3 },
	{ name = "Bruiser", model = "BruiserZombie", baseWeight = 15, weightDecay = 2,  minWeight = 5,  speedMult = 0.6 },
	{ name = "Spitter", model = "SpitterZombie", baseWeight = 5,  weightDecay = 2,  minWeight = 5,  speedMult = 0.7 },
}

local SPAWN_TAG = "ZombieSpawn"
local ENEMY_TAG = "Enemy_Zombie"
local CORPSE_CLEANUP_DELAY = 3

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local templates -- lazy-loaded to let Models replicate into ServerStorage first
local activeZombies = {}

local function ensureTemplates()
	if templates then return end
	templates = {}
	local models = ServerStorage:WaitForChild("Models")
	for _, zType in ZOMBIE_TYPES do
		templates[zType.model] = models:WaitForChild(zType.model)
	end
end

local function pickZombieType(waveNumber)
	local totalWeight = 0
	local weights = {}
	for i, zType in ZOMBIE_TYPES do
		local w = math.max(zType.baseWeight + (waveNumber - 1) * zType.weightDecay, zType.minWeight)
		weights[i] = w
		totalWeight += w
	end
	local roll = math.random() * totalWeight
	local cumulative = 0
	for i, w in weights do
		cumulative += w
		if roll <= cumulative then
			return ZOMBIE_TYPES[i]
		end
	end
	return ZOMBIE_TYPES[1]
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
function WaveSpawner.getSpawnPoints()
	return CollectionService:GetTagged(SPAWN_TAG)
end

function WaveSpawner.getAliveCount()
	local count = 0
	for _ in activeZombies do
		count += 1
	end
	return count
end

function WaveSpawner.areAllDead()
	return next(activeZombies) == nil
end

function WaveSpawner.killAllZombies()
	-- Snapshot to avoid mutating-while-iterating surprises when the
	-- AncestryChanged/Died handlers fire during Destroy().
	local toKill = {}
	for zombie in activeZombies do
		table.insert(toKill, zombie)
	end
	activeZombies = {}

	for _, zombie in toKill do
		if zombie.Parent then
			zombie:Destroy()
		end
	end
end

function WaveSpawner.startWave(waveNumber)
	ensureTemplates()

	local spawnPoints = WaveSpawner.getSpawnPoints()
	if #spawnPoints == 0 then
		warn("[WaveSpawner] No parts tagged '" .. SPAWN_TAG .. "' — wave " .. waveNumber .. " will spawn zero zombies")
		return 0
	end

	local zombieCount = BASE_ZOMBIE_COUNT + (waveNumber * COUNT_INCREMENT)
	local health = BASE_HEALTH + (waveNumber * HEALTH_PER_WAVE)
	local damage = BASE_DAMAGE + (waveNumber * DAMAGE_PER_WAVE)
	local walkSpeed = BASE_WALK_SPEED + (waveNumber * SPEED_PER_WAVE)

	print(string.format(
		"[WaveSpawner] === WAVE %d === | Zombies: %d | HP: %d | DMG: %d | Speed: %.1f",
		waveNumber, zombieCount, health, damage, walkSpeed
	))

	for i = 1, zombieCount do
		local zType = pickZombieType(waveNumber)
		local template = templates[zType.model]
		local clone = template:Clone()

		clone:SetAttribute("ZombieType", zType.name)
		clone:SetAttribute("MaxHealth", health)
		clone:SetAttribute("Damage", damage)
		clone:SetAttribute("WalkSpeed", walkSpeed * zType.speedMult)

		local spawnPart = spawnPoints[math.random(1, #spawnPoints)]
		local rootPart = clone:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
		end

		clone.Parent = workspace
		CollectionService:AddTag(clone, ENEMY_TAG)

		activeZombies[clone] = true

		-- Death: remove from active set and clean up corpse
		local humanoid = clone:WaitForChild("Zombie", 5)
		if humanoid then
			humanoid.Died:Connect(function()
				activeZombies[clone] = nil
				task.delay(CORPSE_CLEANUP_DELAY, function()
					if clone.Parent then
						clone:Destroy()
					end
				end)
			end)
		end

		-- Backup: if something else destroys the zombie, untrack it
		clone.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				activeZombies[clone] = nil
			end
		end)
	end

	return zombieCount
end

return WaveSpawner
