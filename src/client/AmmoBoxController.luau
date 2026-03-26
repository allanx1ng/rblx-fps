-- Handles ammo box pickups via ProximityPrompt.
--
-- Tag any Part in the workspace with the CollectionService tag "AmmoBox"
-- and give it a ProximityPrompt child. This script uses the global
-- ProximityPromptService event, which is reliable from any LocalScript context.
--
-- On use, all guns in the player's Backpack and Character are refilled
-- to their MaxSpareAmmoValue. A per-box cooldown prevents spam.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local AMMO_BOX_TAG = "AmmoBox"
local COOLDOWN = 1 -- seconds before the same box can be used again

local player = Players.LocalPlayer
local boxCooldowns = {} -- [prompt] = true while on cooldown


local function refillAllGuns()
	local containers = { player.Backpack, player.Character }
	for _, container in containers do
		if not container then
			continue
		end
		for _, tool in container:GetChildren() do
			if not tool:IsA("Tool") then continue end
			local spareAmmoValue    = tool:FindFirstChild("SpareAmmoValue")
			local maxSpareAmmoValue = tool:FindFirstChild("MaxSpareAmmoValue")
			if spareAmmoValue and maxSpareAmmoValue then
				spareAmmoValue.Value = maxSpareAmmoValue.Value
			end

			-- local currAmmoValue    = tool:FindFirstChild("AmmoValue")
			-- local maxCurrAmmoValue = tool:FindFirstChild("CapacityValue")
			-- if currAmmoValue and maxCurrAmmoValue then
			-- 	currAmmoValue.Value = maxCurrAmmoValue.Value
			-- end
		end
	end
end

local function isAmmoBox(prompt)
	local parent = prompt.Parent
	while parent do
		if CollectionService:HasTag(parent, AMMO_BOX_TAG) then
			return true
		end
		parent = parent.Parent
	end
	return false
end

print("[AmmoBox] Listening for PromptTriggered")

ProximityPromptService.PromptTriggered:Connect(function(prompt, _player)
	print("[AmmoBox] PromptTriggered fired — prompt:", prompt:GetFullName(), "| player:", _player and _player.Name or "nil")
	if _player ~= player then
		print("[AmmoBox]   Ignoring, triggered by different player")
		return
	end
	if not isAmmoBox(prompt) then
		print("[AmmoBox]   Prompt is not on an AmmoBox tagged instance")
		return
	end
	if boxCooldowns[prompt] then
		print("[AmmoBox]   Box is on cooldown")
		return
	end

	refillAllGuns()

	boxCooldowns[prompt] = true
	prompt.Enabled = false
	task.delay(COOLDOWN, function()
		boxCooldowns[prompt] = nil
		prompt.Enabled = true
	end)
end)

return {}
