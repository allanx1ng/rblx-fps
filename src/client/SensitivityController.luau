-- Single owner of MouseDeltaSensitivity. No other script should write to it.
--
-- Combines:
--   MouseSensitivity (player attribute, 0-100, set by settings slider)
--   FOVSensScale     (player attribute, set by GunHandler for ADS zoom)
--
-- In-game first person: sensitivity * FOV scale
-- Lobby third person:   1 (default)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

RunService.RenderStepped:Connect(function()
	-- TODO: IMPLEMENT AFTER LOBBY/GAME LOGIC DONE
	-- if player:GetAttribute("InGame") and player.CameraMode == Enum.CameraMode.LockFirstPerson then
	local sens = (player:GetAttribute("MouseSensitivity") or 100) / 100
	local fovScale = player:GetAttribute("FOVSensScale") or 1
	UserInputService.MouseDeltaSensitivity = sens * fovScale
	-- else
	-- 	UserInputService.MouseDeltaSensitivity = 1
	-- end
end)

return {}
