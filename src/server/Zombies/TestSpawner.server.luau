-- Dev spawner: spawns one of each zombie type for quick testing
-- Set ENABLED = false when using WaveSpawner

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local ENABLED = true
local SPAWN_POSITION = Vector3.new(-37, 28.8, -120)
local SPACING = 5

local TEST_TYPES = {
	{ name = "Normal",  model = "NormalZombie" },
	{ name = "Runner",  model = "RunnerZombie" },
	{ name = "Bruiser", model = "BruiserZombie" },
	{ name = "Spitter", model = "SpitterZombie" },
}

if not ENABLED then return end

task.wait(1) -- ensure ZombieManager listener is ready

local models = ServerStorage:WaitForChild("Models")

for i, zType in TEST_TYPES do
	local template = models:WaitForChild(zType.model)
	local clone = template:Clone()

	clone:SetAttribute("ZombieType", zType.name)
	clone:SetAttribute("MaxHealth", 100)
	clone:SetAttribute("Damage", 10)

	local offset = Vector3.new((i - 1) * SPACING, 0, 0)
	local rootPart = clone:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = CFrame.new(SPAWN_POSITION + offset)
	end

	clone.Parent = workspace
	CollectionService:AddTag(clone, "Enemy_Zombie")

	print("[TestSpawner] Spawned " .. zType.name .. " (" .. i .. "/" .. #TEST_TYPES .. ")")
end
