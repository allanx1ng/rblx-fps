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
-- Hide and mute the local player's own TP weapon model so it doesn't
-- clip through the first-person view model.
-- (Server plays FireSound on the TP model which replicates to all clients)
-- ---------------------------------------------------------------------------
local RunService = game:GetService("RunService")

local function hideTPWeaponParts(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 1
		end
	end
end

local function setupLocalTPHiding(character)
	local hiddenModels = {}

	local function processChild(child)
		if not child:IsA("Model") then return end
		if child:IsA("Tool") or child:IsA("Accessory") then return end

		-- TP weapon models are welded via GunWeld on the Right Arm,
		-- or can be identified by having a FireSound (server TP weapon)
		local rightArm = character:FindFirstChild("Right Arm")
		local isTPWeapon = false
		if rightArm then
			local gunWeld = rightArm:FindFirstChild("GunWeld")
			if gunWeld and gunWeld.Part1 and gunWeld.Part1:IsDescendantOf(child) then
				isTPWeapon = true
			end
		end
		if not isTPWeapon and child:FindFirstChild("FireSound", true) then
			isTPWeapon = true
		end
		if not isTPWeapon then return end

		-- Mute fire sound
		local fireSound = child:FindFirstChild("FireSound", true)
		if fireSound and fireSound:IsA("Sound") then
			fireSound.Volume = 0
		end
		child.DescendantAdded:Connect(function(desc)
			if desc:IsA("Sound") and desc.Name == "FireSound" then
				desc.Volume = 0
			end
		end)

		-- Hide all parts
		hideTPWeaponParts(child)
		table.insert(hiddenModels, child)
	end

	character.ChildAdded:Connect(processChild)
	for _, child in character:GetChildren() do
		processChild(child)
	end

	-- LocalTransparencyModifier resets every render frame, so re-apply
	RunService.RenderStepped:Connect(function()
		for _, model in hiddenModels do
			if model and model.Parent then
				hideTPWeaponParts(model)
			end
		end
	end)
end

-- Set up hiding/muting for the local player's character
local function onCharacterAdded(character)
	setupLocalTPHiding(character)
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
