local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedPillHandler = require(ReplicatedStorage.Shared.SpeedPillHandler)
local config = require(ReplicatedStorage.Shared.Items.Actives.SpeedPill)

local pill = SpeedPillHandler.new(script.Parent, config)
pill:init()
