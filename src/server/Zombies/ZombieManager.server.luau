local CollectionService = game:GetService("CollectionService")

local root = script.Parent :: Instance

-- Require Common Systems
local Common = root:FindFirstChild("Common")
assert(Common, "Common folder not found")

local Health = require(Common:FindFirstChild("Health"))
local Pathfinding = require(Common:FindFirstChild("Pathfinding"))
local Animate = require(Common:FindFirstChild("Animate"))
local Sound = require(Common:FindFirstChild("Sound"))
local Attack = require(Common:FindFirstChild("Attack"))

-- Require Specific Types
local Types = root:FindFirstChild("Types")
assert(Types, "Types folder not found")

local ZombieTypes = {
    Normal = require(Types:FindFirstChild("Normal")),
    Runner = require(Types:FindFirstChild("Runner")),
    Tank = require(Types:FindFirstChild("Tank")),
    Spitter = require(Types:FindFirstChild("Spitter")),
}

local MASTER_TAG = "Enemy_Zombie"

local function onZombieAdded(zombieModel)
    -- Read the attributes set in Studio
    local typeName = zombieModel:GetAttribute("ZombieType") or "Normal"
    local maxHealth = zombieModel:GetAttribute("MaxHealth") or 100

    -- 1. Setup Common Systems for EVERY zombie
    Health.Initialize(zombieModel, maxHealth)
    Pathfinding.Initialize(zombieModel)
    Animate.Initialize(zombieModel)
    Sound.Initialize(zombieModel)
    Attack.Initialize(zombieModel)

    -- 2. Route to Specific Behavior
    local specificModule = ZombieTypes[typeName]
    if specificModule then
        specificModule.Initialize(zombieModel)
    else
        warn("No specific logic found for zombie type: " .. typeName)
    end
end

CollectionService:GetInstanceAddedSignal(MASTER_TAG):Connect(onZombieAdded)
