local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HealingPotionHandler = require(ReplicatedStorage.Shared.HealingPotionHandler)
local config = require(ReplicatedStorage.Shared.Items.Actives.HealingPotion)

local potion = HealingPotionHandler.new(script.Parent, config)
potion:init()
