--[[
	ThirdPersonPose — server-side third-person gun holding poses.

	- Listens for tool equip/unequip on each player's character
	- When a gun tool is equipped: applies arm pose, welds weapon model, rotates torso
	- When unequipped: restores original Motor6Ds so animations resume
	- Broadcasts gunfire effects to other players
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guns = ReplicatedStorage.Shared.Guns
local Melee = ReplicatedStorage.Shared:WaitForChild("Melee")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GunFiredRemote = Remotes:WaitForChild("GunFired")
local GunFiredEffectRemote = Remotes:WaitForChild("GunFiredEffect")

-- ---------------------------------------------------------------------------
-- Pose presets — arm C1 values + torso yaw for rifle vs pistol holds
-- ---------------------------------------------------------------------------
-- Arm CFrame for each pose type (at origin). Used with gun offset to compute weld C0.
-- These represent the arm's local CFrame when the pose is applied.
local RIFLE_POSE = {
	yaw = math.rad(45),
	rightC1 = CFrame.new(-0.346, 0.903, -0.053)
		* CFrame.fromOrientation(math.rad(-45), math.rad(90), math.rad(-90)),
	leftC1 = CFrame.new(-0.27, 1.242, -0.062)
		* CFrame.fromOrientation(math.rad(0), math.rad(15), math.rad(105)),
	-- Arm CFrame from the posed dummy rig (position zeroed out, orientation kept)
	armCF = CFrame.new(0, 0, 0)
		* CFrame.fromOrientation(math.rad(90), math.rad(0), math.rad(0)),
	-- Gun orientation for all rifles (same across all rifles)
	gunOrientation = CFrame.fromOrientation(math.rad(0), math.rad(0), math.rad(0)),
}

local PISTOL_POSE = {
	yaw = math.rad(30),
	rightC1 = CFrame.new(-0.461, 1.247, 0)
		* CFrame.fromOrientation(math.rad(-45), math.rad(90), math.rad(-90)),
	leftC1 = CFrame.new(0.26, 0.68, -0.219)
		* CFrame.fromOrientation(math.rad(-14.477), math.rad(-123.967), math.rad(105.504)),
	-- Arm CFrame from the posed dummy rig (position zeroed out, orientation kept)
	armCF = CFrame.new(0, 0, 0)
		* CFrame.fromOrientation(math.rad(90), math.rad(15), math.rad(0)),
	-- Gun orientation for all pistols (same across all pistols)
	gunOrientation = CFrame.fromOrientation(math.rad(0), math.rad(0), math.rad(0)),
}

-- ---------------------------------------------------------------------------
-- Per-character state
-- ---------------------------------------------------------------------------
local characterState = {} -- [character] -> state table

local function getState(character)
	if not characterState[character] then
		characterState[character] = {
			isPosed = false,
			currentGunName = nil,
			currentGunModel = nil,
			savedRightC0 = nil,
			savedRightC1 = nil,
			savedLeftC0 = nil,
			savedLeftC1 = nil,
			savedRootC0 = nil,
			savedNeckC0 = nil,
		}
	end
	return characterState[character]
end

-- ---------------------------------------------------------------------------
-- Weld the third-person weapon model to the right arm
-- ---------------------------------------------------------------------------
local function weldWeapon(character, toolName, config)
	local state = getState(character)

	local folder = ReplicatedStorage:FindFirstChild("ThirdPersonWeapons")
	if not folder then return end
	local template = folder:FindFirstChild(toolName)
	if not template then return end

	local rightArm = character:FindFirstChild("Right Arm")
	if not rightArm then return end

	local gun = template:Clone()
	for _, part in gun:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end

	-- Compute weld C0 at runtime from the gun's position offset
	-- Config stores thirdPersonGunOffset: the gun position minus arm position from the posed dummy
	-- Pose stores armCF (arm orientation at origin) and gunOrientation (same for all guns in class)
	local poseType = config.thirdPersonPoseType or "rifle"
	local pose = poseType == "pistol" and PISTOL_POSE or RIFLE_POSE
	local gunOffset = config.thirdPersonGunOffset or Vector3.new(-0.418, 0.32, -0.377)
	local armCF = pose.armCF
	local gunCF = CFrame.new(gunOffset) * pose.gunOrientation
	local weldC0 = armCF:ToObjectSpace(gunCF)

	local gunWeld = Instance.new("Weld")
	gunWeld.Name = "GunWeld"
	gunWeld.Part0 = rightArm
	gunWeld.Part1 = gun.PrimaryPart
	gunWeld.C0 = weldC0
	gunWeld.Parent = rightArm
	gun.Parent = character

	state.currentGunName = toolName
	state.currentGunModel = gun
end

-- ---------------------------------------------------------------------------
-- Remove the current weapon model from the character
-- ---------------------------------------------------------------------------
local function removeWeapon(character)
	local state = characterState[character]
	if not state then return end

	if state.currentGunModel then
		state.currentGunModel:Destroy()
		state.currentGunModel = nil
	end

	local rightArm = character:FindFirstChild("Right Arm")
	if rightArm then
		local gunWeld = rightArm:FindFirstChild("GunWeld")
		if gunWeld then gunWeld:Destroy() end
	end

	state.currentGunName = nil
end

-- ---------------------------------------------------------------------------
-- Apply gun pose — replace Motor6Ds with Welds, rotate torso
-- ---------------------------------------------------------------------------
local function applyGunPose(character, toolName)
	local configModule = Guns:FindFirstChild(toolName)
	if not configModule then return end
	local config = require(configModule)

	local state = getState(character)
	local poseType = config.thirdPersonPoseType or "rifle"
	local pose = poseType == "pistol" and PISTOL_POSE or RIFLE_POSE

	if state.isPosed then
		-- Already posed — swap weapon model and update arm pose / yaw if needed
		removeWeapon(character)

		local torso = character:FindFirstChild("Torso")
		if torso then
			local rightWeld = torso:FindFirstChild("Right Shoulder")
			if rightWeld then rightWeld.C1 = pose.rightC1 end
			local leftWeld = torso:FindFirstChild("Left Shoulder")
			if leftWeld then leftWeld.C1 = pose.leftC1 end

			-- Update torso yaw if pose type changed
			local yaw = pose.yaw
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local rootJoint = hrp:FindFirstChild("RootJoint")
				if rootJoint and state.savedRootC0 then
					rootJoint.C0 = state.savedRootC0 * CFrame.Angles(0, 0, -yaw)
				end
			end
			local neck = torso:FindFirstChild("Neck")
			if neck and state.savedNeckC0 then
				neck.C0 = state.savedNeckC0 * CFrame.Angles(0, 0, yaw)
			end
		end

		weldWeapon(character, toolName, config)
		return
	end

	-- Fresh pose: save originals and replace Motor6Ds with Welds
	local torso = character:FindFirstChild("Torso")
	local rightArm = character:FindFirstChild("Right Arm")
	local leftArm = character:FindFirstChild("Left Arm")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not (torso and rightArm and leftArm and hrp) then return end

	local rightShoulder = torso:FindFirstChild("Right Shoulder")
	local leftShoulder = torso:FindFirstChild("Left Shoulder")
	local neck = torso:FindFirstChild("Neck")
	local rootJoint = hrp:FindFirstChild("RootJoint")
	if not (rightShoulder and leftShoulder and neck and rootJoint) then return end

	-- Save original Motor6D values for restoration
	state.savedRightC0 = rightShoulder.C0
	state.savedRightC1 = rightShoulder.C1
	state.savedLeftC0 = leftShoulder.C0
	state.savedLeftC1 = leftShoulder.C1
	state.savedRootC0 = rootJoint.C0
	state.savedNeckC0 = neck.C0

	-- Destroy Motor6Ds and replace with Welds (locks arm position)
	local rightC0 = rightShoulder.C0
	local leftC0 = leftShoulder.C0
	rightShoulder:Destroy()
	leftShoulder:Destroy()

	local rightWeld = Instance.new("Weld")
	rightWeld.Name = "Right Shoulder"
	rightWeld.Part0 = torso
	rightWeld.Part1 = rightArm
	rightWeld.C0 = rightC0
	rightWeld.C1 = pose.rightC1
	rightWeld.Parent = torso

	local leftWeld = Instance.new("Weld")
	leftWeld.Name = "Left Shoulder"
	leftWeld.Part0 = torso
	leftWeld.Part1 = leftArm
	leftWeld.C0 = leftC0
	leftWeld.C1 = pose.leftC1
	leftWeld.Parent = torso

	-- Apply torso yaw
	local yaw = pose.yaw
	rootJoint.C0 = state.savedRootC0 * CFrame.Angles(0, 0, -yaw)
	neck.C0 = state.savedNeckC0 * CFrame.Angles(0, 0, yaw)

	state.isPosed = true

	-- Weld weapon model
	weldWeapon(character, toolName, config)
end

-- ---------------------------------------------------------------------------
-- Remove gun pose — restore original Motor6Ds
-- ---------------------------------------------------------------------------
local function removeGunPose(character)
	local state = characterState[character]
	if not state or not state.isPosed then return end

	-- Remove weapon model
	removeWeapon(character)

	local torso = character:FindFirstChild("Torso")
	local rightArm = character:FindFirstChild("Right Arm")
	local leftArm = character:FindFirstChild("Left Arm")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not (torso and rightArm and leftArm and hrp) then
		state.isPosed = false
		return
	end

	-- Remove replacement Welds
	local rightWeld = torso:FindFirstChild("Right Shoulder")
	if rightWeld and rightWeld:IsA("Weld") then rightWeld:Destroy() end
	local leftWeld = torso:FindFirstChild("Left Shoulder")
	if leftWeld and leftWeld:IsA("Weld") then leftWeld:Destroy() end

	-- Recreate Motor6Ds with saved values
	if state.savedRightC0 then
		local motor = Instance.new("Motor6D")
		motor.Name = "Right Shoulder"
		motor.Part0 = torso
		motor.Part1 = rightArm
		motor.C0 = state.savedRightC0
		motor.C1 = state.savedRightC1
		motor.Parent = torso
	end

	if state.savedLeftC0 then
		local motor = Instance.new("Motor6D")
		motor.Name = "Left Shoulder"
		motor.Part0 = torso
		motor.Part1 = leftArm
		motor.C0 = state.savedLeftC0
		motor.C1 = state.savedLeftC1
		motor.Parent = torso
	end

	-- Restore original RootJoint and Neck
	local rootJoint = hrp:FindFirstChild("RootJoint")
	if rootJoint and state.savedRootC0 then
		rootJoint.C0 = state.savedRootC0
	end
	local neck = torso:FindFirstChild("Neck")
	if neck and state.savedNeckC0 then
		neck.C0 = state.savedNeckC0
	end

	state.isPosed = false
end

-- ---------------------------------------------------------------------------
-- Character setup — listen for tool equip/unequip
-- ---------------------------------------------------------------------------
local function setupCharacter(character)
	-- Strip custom body meshes to force default blocky R6 shape
	for _, child in character:GetChildren() do
		if child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
	character.ChildAdded:Connect(function(child)
		if child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end)

	-- Track tool equip/unequip via ChildAdded/ChildRemoved
	-- When a Tool is parented to the character, it is "equipped" (in hand)
	character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then return end

		local isGun = Guns:FindFirstChild(child.Name) ~= nil
		local isMelee = Melee:FindFirstChild(child.Name) ~= nil
		if isGun then
			applyGunPose(character, child.Name)
		elseif isMelee then
			-- Melee: restore Motor6Ds so animations can drive arms.
			-- Roblox handles the Handle grip and slash animation natively.
			removeGunPose(character)
		else
			-- Non-weapon tool equipped (e.g. HealingPotion) — remove gun pose
			removeGunPose(character)
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if not child:IsA("Tool") then return end

		-- Defer to handle weapon swap without visual flicker:
		-- ChildRemoved fires for old tool before ChildAdded fires for new tool.
		-- By deferring, we check if a new weapon is already in the character.
		task.defer(function()
			if not character.Parent then return end -- character was destroyed

			-- Check if another weapon tool is now equipped
			for _, c in character:GetChildren() do
				if c:IsA("Tool") then
					if Guns:FindFirstChild(c.Name) or Melee:FindFirstChild(c.Name) then
						return -- another weapon is equipped; ChildAdded handles it
					end
				end
			end

			-- No weapon tool found — remove pose and weapon model
			removeGunPose(character)
		end)
	end)
end

-- ---------------------------------------------------------------------------
-- Gun fired — play sound on TP model, broadcast muzzle flash to clients
-- ---------------------------------------------------------------------------
local lastFireTime = {} -- [player] -> tick

GunFiredRemote.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local state = characterState[character]
	if not state or not state.isPosed or not state.currentGunModel then return end

	-- Rate limit based on equipped gun's fire rate
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then return end
	local configModule = Guns:FindFirstChild(tool.Name)
	if not configModule then return end
	local config = require(configModule)

	local now = tick()
	local last = lastFireTime[player] or 0
	if (now - last) < config.fireRate * 0.8 then return end
	lastFireTime[player] = now

	-- Play fire sound on the TP weapon model (replicates to all clients via Roblox)
	local fireSound = state.currentGunModel:FindFirstChild("FireSound", true)
	if fireSound then
		fireSound:Play()
	end

	-- Broadcast muzzle flash effect to all clients
	GunFiredEffectRemote:FireAllClients(character)
end)

-- ---------------------------------------------------------------------------
-- Player lifecycle
-- ---------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		setupCharacter(character)
	end)

	player.CharacterRemoving:Connect(function(character)
		characterState[character] = nil
	end)

	if player.Character then
		setupCharacter(player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastFireTime[player] = nil
	if player.Character then
		characterState[player.Character] = nil
	end
end)
