-- Registers collision groups and assigns parts to them.
--
-- Groups:
--   ViewModel       — client first-person viewmodels, collides with nothing
--   PlayerCharacter — player rigs (so barriers can target them)
--   ZombieBarrier   — blocks players, lets zombies/projectiles pass
--                     (barrier parts are tagged "ZombieBarrier")

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")

PhysicsService:RegisterCollisionGroup("ViewModel")
PhysicsService:CollisionGroupSetCollidable("ViewModel", "Default", false)

PhysicsService:RegisterCollisionGroup("PlayerCharacter")
PhysicsService:CollisionGroupSetCollidable("PlayerCharacter", "Default", true)
PhysicsService:CollisionGroupSetCollidable("PlayerCharacter", "PlayerCharacter", true)

PhysicsService:RegisterCollisionGroup("ZombieBarrier")
PhysicsService:CollisionGroupSetCollidable("ZombieBarrier", "Default", false)
PhysicsService:CollisionGroupSetCollidable("ZombieBarrier", "PlayerCharacter", true)
PhysicsService:CollisionGroupSetCollidable("ZombieBarrier", "ViewModel", false)

-- ---------------------------------------------------------------------------
-- Player character collision group
-- ---------------------------------------------------------------------------
local function assignPlayerCollisionGroup(character)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "PlayerCharacter"
		end
	end
	character.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			desc.CollisionGroup = "PlayerCharacter"
		end
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(assignPlayerCollisionGroup)
	if player.Character then
		assignPlayerCollisionGroup(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end

-- ---------------------------------------------------------------------------
-- ZombieBarrier — applied to anything tagged "ZombieBarrier"
-- ---------------------------------------------------------------------------
local BARRIER_TAG = "ZombieBarrier"

local function configureBarrierPart(p)
	p.CollisionGroup = "ZombieBarrier"
	p.CanQuery = false  -- hitscan raycasts pass through
	p.CanTouch = false  -- projectile .Touched doesn't fire on barriers
end

local function applyBarrierGroup(part)
	if part:IsA("BasePart") then
		configureBarrierPart(part)
	elseif part:IsA("Model") then
		for _, child in part:GetDescendants() do
			if child:IsA("BasePart") then
				configureBarrierPart(child)
			end
		end
	end
end

for _, obj in CollectionService:GetTagged(BARRIER_TAG) do
	applyBarrierGroup(obj)
end
CollectionService:GetInstanceAddedSignal(BARRIER_TAG):Connect(applyBarrierGroup)
