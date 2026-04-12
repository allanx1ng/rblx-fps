--[[
	ThirdPersonEffects — handles muzzle flash and light effects on other
	players' third-person weapon models when they fire.

	- Listens for GunFiredEffect from the server
	- For other players: emits muzzle particles and flashes lights
	- For the local player: skips (first-person ViewModelController handles it)
	- Mutes the local player's own TP gun FireSound to prevent double audio
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local GunFiredEffectRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GunFiredEffect")

-- ---------------------------------------------------------------------------
-- Mute the local player's own TP gun sounds to prevent double audio
-- (Server plays FireSound on the TP model which replicates to all clients)
-- ---------------------------------------------------------------------------
local function muteTPGunSounds(character)
	-- Watch for any model added to the character that has a FireSound
	-- (third-person weapon models are cloned by the server)
	character.ChildAdded:Connect(function(child)
		if not child:IsA("Model") then return end

		-- Check if this model has a FireSound (indicates a TP weapon)
		local fireSound = child:FindFirstChild("FireSound", true)
		if fireSound and fireSound:IsA("Sound") then
			fireSound.Volume = 0
		end

		-- Also catch sounds added after the model is parented
		child.DescendantAdded:Connect(function(desc)
			if desc:IsA("Sound") and desc.Name == "FireSound" then
				desc.Volume = 0
			end
		end)
	end)

	-- Handle models already present (in case of late setup)
	for _, child in character:GetChildren() do
		if child:IsA("Model") then
			local fireSound = child:FindFirstChild("FireSound", true)
			if fireSound and fireSound:IsA("Sound") then
				fireSound.Volume = 0
			end
		end
	end
end

-- Set up muting for the local player's character
local function onCharacterAdded(character)
	muteTPGunSounds(character)
end

if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ---------------------------------------------------------------------------
-- Handle muzzle flash effects for other players' TP weapons
-- ---------------------------------------------------------------------------
GunFiredEffectRemote.OnClientEvent:Connect(function(character)
	-- Skip effects on our own character (first-person ViewModel handles it)
	if character == localPlayer.Character then return end
	if not character or not character.Parent then return end

	-- Find the TP weapon model in the character (a Model child with a MuzzlePoint)
	local gunModel = nil
	for _, child in character:GetChildren() do
		if child:IsA("Model") and child:FindFirstChild("MuzzlePoint", true) then
			gunModel = child
			break
		end
	end
	if not gunModel then return end

	local muzzlePoint = gunModel:FindFirstChild("MuzzlePoint", true)
	if not muzzlePoint then return end

	-- Emit muzzle flash particles
	local emitter = muzzlePoint:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter:Emit(6)
	end

	-- Flash muzzle lights briefly
	local lights = {}
	for _, obj in muzzlePoint:GetChildren() do
		if obj:IsA("PointLight") or obj:IsA("SpotLight") then
			table.insert(lights, obj)
		end
	end

	if #lights > 0 then
		for _, light in lights do
			light.Enabled = true
		end
		task.delay(0.05, function()
			for _, light in lights do
				if light and light.Parent then
					light.Enabled = false
				end
			end
		end)
	end
end)

return true
