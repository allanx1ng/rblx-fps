-- Simple dev spawner: clones a zombie on a timer for testing
-- Set ENABLED = false when using WaveSpawner

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local ENABLED = true
local SPAWN_INTERVAL = 10
local MAX_ZOMBIES = 10
local SPAWN_POSITION = Vector3.new(-37, 28.8, -120)

if not ENABLED then return end

local template = ServerStorage:WaitForChild("Models"):WaitForChild("RunnerZombie")
local activeZombies = {}

local function cleanupDead()
	local alive = {}
	for _, zombie in activeZombies do
		if zombie.Parent then
			table.insert(alive, zombie)
		end
	end
	activeZombies = alive
end

local function spawnZombie()
	cleanupDead()

	if #activeZombies >= MAX_ZOMBIES then
		return
	end

	local clone = template:Clone()
	clone:SetAttribute("ZombieType", "Runner")
	clone:SetAttribute("MaxHealth", 100)
	clone:SetAttribute("Damage", 10)

	local rootPart = clone:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = CFrame.new(SPAWN_POSITION)
	end

	clone.Parent = workspace
	CollectionService:AddTag(clone, "Enemy_Zombie")
	table.insert(activeZombies, clone)

	print("[TestSpawner] Spawned zombie (" .. #activeZombies .. "/" .. MAX_ZOMBIES .. ")")
end

while true do
	spawnZombie()
	task.wait(SPAWN_INTERVAL)
end
