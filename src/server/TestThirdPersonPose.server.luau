--[[
	Test script: applies a static gun-holding pose to every player's R6 character.
	Delete when done testing.

	- Overrides arm C1 values for a holding pose
	- Rotates torso 45° right via RootJoint C0
	- Counter-rotates head so it faces forward via Neck C0
	- Strips custom body meshes to force blocky R6 shape
	- Gun welding is done manually in Studio for now
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TORSO_YAW = math.rad(30)

local function setupCharacter(character)
	local torso = character:WaitForChild("Torso")
	local rightArm = character:WaitForChild("Right Arm")
	local leftArm = character:WaitForChild("Left Arm")
	local hrp = character:WaitForChild("HumanoidRootPart")

	local rightShoulder = torso:WaitForChild("Right Shoulder")
	local leftShoulder = torso:WaitForChild("Left Shoulder")
	local neck = torso:WaitForChild("Neck")
	local rootJoint = hrp:WaitForChild("RootJoint")

	-- Save original C0 values before destroying the Motor6Ds
	local rightC0 = rightShoulder.C0
	local leftC0 = leftShoulder.C0
	local origRootC0 = rootJoint.C0
	local origNeckC0 = neck.C0

	-- Posed C1 values
	local newRightC1 = CFrame.new(-0.461, 1.247, 0)
		* CFrame.fromOrientation(math.rad(-45), math.rad(90), math.rad(-90))
	local newLeftC1 = CFrame.new(0.26, 0.68, -0.219)
		* CFrame.fromOrientation(math.rad(-14.477), math.rad(-123.967), math.rad(105.504))

	-- Gun weld C0: exact value from arm.CFrame:ToObjectSpace(gun.CFrame) on posed rig
	local GUN_WELD_C0 = CFrame.new(
		-0.306838989, -0.471988678, -0.319972992,
		0.965927005, 2.47837738e-06, -0.258816451,
		0.258815497, 2.47127855e-06, 0.965927958,
		4.1676617e-06, -1.00000048, 3.81267205e-06
	)

	-- Clone and weld gun to arm BEFORE applying pose transforms
	local folder = ReplicatedStorage:FindFirstChild("ThirdPersonWeapons")
	if not folder then return end
	local template = folder:FindFirstChild("M9")
	if not template then return end

	local gun = template:Clone()
	for _, part in gun:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end

	local gunWeld = Instance.new("Weld")
	gunWeld.Name = "GunWeld"
	gunWeld.Part0 = rightArm
	gunWeld.Part1 = gun.PrimaryPart
	gunWeld.C0 = GUN_WELD_C0
	gunWeld.Parent = rightArm
	gun.Parent = character

	-- Now apply arm pose and torso rotation — gun follows via weld
	rightShoulder:Destroy()
	leftShoulder:Destroy()

	local rightWeld = Instance.new("Weld")
	rightWeld.Name = "Right Shoulder"
	rightWeld.Part0 = torso
	rightWeld.Part1 = rightArm
	rightWeld.C0 = rightC0
	rightWeld.C1 = newRightC1
	rightWeld.Parent = torso

	local leftWeld = Instance.new("Weld")
	leftWeld.Name = "Left Shoulder"
	leftWeld.Part0 = torso
	leftWeld.Part1 = leftArm
	leftWeld.C0 = leftC0
	leftWeld.C1 = newLeftC1
	leftWeld.Parent = torso

	-- Torso 45° right, head compensates to face forward
	rootJoint.C0 = origRootC0 * CFrame.Angles(0, 0, -TORSO_YAW)
	neck.C0 = origNeckC0 * CFrame.Angles(0, 0, TORSO_YAW)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
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

		task.wait(0.5)
		setupCharacter(character)
	end)

	if player.Character then
		setupCharacter(player.Character)
	end
end)
