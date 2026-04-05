local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Lock camera to first person
-- player.CameraMode = Enum.CameraMode.LockFirstPerson

-- Hide default cursor; the Crosshair ScreenGui takes over
UserInputService.MouseIconEnabled = false

-- Disable default Roblox UI
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)


-- Each controller is spawned independently so a WaitForChild in one
-- can never block the others from starting.
task.spawn(require, script.CrosshairController)
task.spawn(require, script.GunUIController)
task.spawn(require, script.SprintController)
task.spawn(require, script.CrouchController)
task.spawn(require, script.AmmoBoxController)
task.spawn(require, script.ProjectileHider)
task.spawn(require, script.SensitivityController)
task.spawn(require, script.ToolCleanupController)
task.spawn(require, script.InventoryController)
task.spawn(require, script.SpitterProjectileController)
