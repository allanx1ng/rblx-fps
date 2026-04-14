local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeHandler = require(ReplicatedStorage.Shared.MeleeHandler)
local config = require(ReplicatedStorage.Shared.Melee[script.Parent.Name])

local melee = MeleeHandler.new(script.Parent, config)
melee:init()
