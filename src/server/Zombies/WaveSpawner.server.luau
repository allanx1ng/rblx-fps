-- Wave-based zombie spawner with scaling difficulty and mixed types
-- Set ENABLED = true for actual gameplay, false when using TestSpawner

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local ENABLED = true
local INTERMISSION_TIME = 5
local BASE_ZOMBIE_COUNT = 3
local COUNT_INCREMENT = 2

-- Base stats (wave 1 values)
local BASE_HEALTH = 100
local BASE_DAMAGE = 10
local BASE_WALK_SPEED = 16

-- Scaling per wave
local HEALTH_PER_WAVE = 15
local DAMAGE_PER_WAVE = 2
local SPEED_PER_WAVE = 0.3

-- Type definitions with weighted probability
local ZOMBIE_TYPES = {
	{ name = "Normal",  model = "NormalZombie",  baseWeight = 50, weightDecay = -3, minWeight = 10, speedMult = 1.0 },
	{ name = "Runner",  model = "RunnerZombie",  baseWeight = 30, weightDecay = -1, minWeight = 10, speedMult = 1.3 },
	{ name = "Bruiser", model = "BruiserZombie", baseWeight = 15, weightDecay = 2,  minWeight = 5,  speedMult = 0.6 },
	{ name = "Spitter", model = "SpitterZombie", baseWeight = 5,  weightDecay = 2,  minWeight = 5,  speedMult = 0.7 },
}

if not ENABLED then return end

-- Load all zombie templates
local models = ServerStorage:WaitForChild("Models")
local templates = {}
for _, zType in ZOMBIE_TYPES do
	templates[zType.model] = models:WaitForChild(zType.model)
end

local SPAWN_TAG = "ZombieSpawn"

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

local function getSpawnPoints()
	return CollectionService:GetTagged(SPAWN_TAG)
end

local function waitForSpawnPoints()
	while #getSpawnPoints() == 0 do
		warn("[WaveSpawner] No Parts tagged '" .. SPAWN_TAG .. "' found. Waiting...")
		task.wait(5)
	end
end

local function startWave(waveNumber)
	local spawnPoints = getSpawnPoints()
	if #spawnPoints == 0 then
		warn("[WaveSpawner] No spawn points available!")
		return
	end

	local zombieCount = BASE_ZOMBIE_COUNT + (waveNumber * COUNT_INCREMENT)
	local health = BASE_HEALTH + (waveNumber * HEALTH_PER_WAVE)
	local damage = BASE_DAMAGE + (waveNumber * DAMAGE_PER_WAVE)
	local walkSpeed = BASE_WALK_SPEED + (waveNumber * SPEED_PER_WAVE)

	print(string.format(
		"[WaveSpawner] === WAVE %d === | Zombies: %d | HP: %d | DMG: %d | Speed: %.1f",
		waveNumber, zombieCount, health, damage, walkSpeed
	))

	local aliveCount = zombieCount

	for i = 1, zombieCount do
		local zType = pickZombieType(waveNumber)
		local template = templates[zType.model]
		local clone = template:Clone()

		clone:SetAttribute("ZombieType", zType.name)
		clone:SetAttribute("MaxHealth", health)
		clone:SetAttribute("Damage", damage)
		clone:SetAttribute("WalkSpeed", walkSpeed * zType.speedMult)

		-- Pick a random spawn point
		local spawnPart = spawnPoints[math.random(1, #spawnPoints)]
		local rootPart = clone:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
		end

		clone.Parent = workspace
		CollectionService:AddTag(clone, "Enemy_Zombie")

		-- Track death
		local humanoid = clone:WaitForChild("Zombie")
		humanoid.Died:Connect(function()
			aliveCount = aliveCount - 1
			print("[WaveSpawner] " .. zType.name .. " down! " .. aliveCount .. " remaining in wave " .. waveNumber)

			-- Clean up corpse after a short delay
			task.delay(3, function()
				if clone.Parent then
					clone:Destroy()
				end
			end)
		end)
	end

	-- Wait for all zombies to die
	while aliveCount > 0 do
		task.wait(1)
	end

	print("[WaveSpawner] Wave " .. waveNumber .. " cleared!")
end

-- Main loop
waitForSpawnPoints()
print("[WaveSpawner] Spawn points found. Starting waves...")
task.wait(3) -- brief delay before first wave

local waveNumber = 1
while true do
	startWave(waveNumber)
	print("[WaveSpawner] Next wave in " .. INTERMISSION_TIME .. " seconds...")
	task.wait(INTERMISSION_TIME)
	waveNumber = waveNumber + 1
end
