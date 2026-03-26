print("[TestGun2] GunScript started")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunHandler = require(ReplicatedStorage.Shared.GunHandler)
local config = require(ReplicatedStorage.Shared.Guns.TestGun2)

print("[TestGun2] Config loaded, autoFire:", config.autoFire)

local gun = GunHandler.new(script.Parent, config)
gun:init()

print("[TestGun2] init() complete")

script.Parent.Equipped:Connect(function()
	print("[TestGun2] Tool equipped")
end)
