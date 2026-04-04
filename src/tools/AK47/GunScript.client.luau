local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunHandler = require(ReplicatedStorage.Shared.GunHandler)
local config = require(ReplicatedStorage.Shared.Guns.AK47)

local gun = GunHandler.new(script.Parent, config)
gun:init()
