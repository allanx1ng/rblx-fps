local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewModelController = {}

local VM_COLLISION_GROUP = "ViewModel"

local activeModel    = nil
local activeConfig   = nil
local rootPart       = nil
local computedAdsOffset = CFrame.new()
local renderConnection  = nil
local adsProgress    = 0
local isADS          = false
local recoilOffset   = CFrame.new()
local equipProgress  = 1  -- 0 = just equipped (arms down), 1 = fully raised

-- Melee swing state
local swingOffset    = CFrame.new()
local swingTime      = -1  -- negative = not swinging
local swingDuration  = 0.4 -- overridden per swing

-- Effect references, found after cloning
local muzzlePoint       = nil
local muzzleWorldPos    = nil  -- cached each RenderStepped to avoid physics-frame drift
local muzzleEmitter  = nil
local muzzleLights    = nil
local fireSound      = nil
local reloadSound    = nil
local emptySound     = nil

local function destroyActive()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if activeModel then
		-- Model may already be destroyed if the camera was replaced
		pcall(function() activeModel:Destroy() end)
		activeModel = nil
	end
	rootPart        = nil
	computedAdsOffset = CFrame.new()
	adsProgress     = 0
	equipProgress   = 0
	recoilOffset    = CFrame.new()
	swingOffset     = CFrame.new()
	swingTime       = -1
	muzzlePoint     = nil
	muzzleWorldPos  = nil
	muzzleEmitter   = nil
	muzzleLights    = nil
	fireSound       = nil
	reloadSound     = nil
	emptySound      = nil
	-- NOTE: activeConfig and isADS are intentionally NOT reset here so
	-- the camera-replacement handler can re-show with the same state.
end

local function getSightLocalPos(root)
	local sight = root.Parent:FindFirstChild("SightPoint", true)
	if not sight then return Vector3.zero end
	return root.CFrame:PointToObjectSpace(sight.WorldPosition)
end

function ViewModelController.show(config)
	destroyActive()
	if not config.viewModelName then return end

	local viewModels = ReplicatedStorage:FindFirstChild("ViewModels")
	local template = viewModels and viewModels:FindFirstChild(config.viewModelName)
	if not template then
		warn("ViewModelController: no model named", config.viewModelName, "in ReplicatedStorage.ViewModels")
		return
	end

	activeConfig = config
	activeModel  = template:Clone()

	-- Apply the local player's clothing to the viewmodel arms.
	-- Shirt/Pants textures require R6 part names (Left Arm, Right Arm, Torso).
	-- Also apply body colors directly to arm parts as a fallback.
	local character = Players.LocalPlayer.Character
	if character then
		-- Clone clothing objects into the viewmodel
		local shirt = character:FindFirstChildOfClass("Shirt")
		if shirt then
			shirt:Clone().Parent = activeModel
		end

		local pants = character:FindFirstChildOfClass("Pants")
		if pants then
			pants:Clone().Parent = activeModel
		end

		local bodyColors = character:FindFirstChildOfClass("BodyColors")
		if bodyColors then
			bodyColors:Clone().Parent = activeModel
		end

		-- Apply arm colors directly as a fallback (works for both R6 and R15 characters)
		local leftArmColor, rightArmColor
		if bodyColors then
			leftArmColor = bodyColors.LeftArmColor3
			rightArmColor = bodyColors.RightArmColor3
		else
			-- R15: read color from the actual arm parts
			local lArm = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("Left Arm")
			local rArm = character:FindFirstChild("RightLowerArm") or character:FindFirstChild("Right Arm")
			leftArmColor = lArm and lArm.Color or Color3.fromRGB(253, 234, 141)
			rightArmColor = rArm and rArm.Color or Color3.fromRGB(253, 234, 141)
		end

		for _, part in activeModel:GetDescendants() do
			if part:IsA("BasePart") then
				if part.Name == "Left Arm" then
					part.Color = leftArmColor
				elseif part.Name == "Right Arm" then
					part.Color = rightArmColor
				end
			end
		end
	end

	-- Shirt/Pants rendering requires a Humanoid and a Torso part in the model.
	if not activeModel:FindFirstChild("Torso") then
		local fakeTorso = Instance.new("Part")
		fakeTorso.Name = "Torso"
		fakeTorso.Size = Vector3.new(0.01, 0.01, 0.01)
		fakeTorso.Transparency = 1
		fakeTorso.CanCollide = false
		fakeTorso.Anchored = true
		fakeTorso.Parent = activeModel
	end

	-- Humanoid is needed for shirt/pants rendering
	local vmHumanoid = activeModel:FindFirstChildOfClass("Humanoid")
	if not vmHumanoid then
		vmHumanoid = Instance.new("Humanoid")
		vmHumanoid.Parent = activeModel
	end
	vmHumanoid.MaxHealth = 0
	vmHumanoid.Health = 0
	vmHumanoid.EvaluateStateMachine = false
	vmHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	vmHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	-- Assign all parts to the ViewModel collision group so Humanoid can't cause collisions
	for _, part in activeModel:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = VM_COLLISION_GROUP
			part.CanTouch = false
			part.CanQuery = false
		end
	end

	activeModel.Parent = workspace.CurrentCamera

	-- Catch any parts added later (Humanoid can create them)
	activeModel.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			desc.CollisionGroup = VM_COLLISION_GROUP
			desc.CanTouch = false
			desc.CanQuery = false
		end
	end)

	rootPart = activeModel:FindFirstChild("RootPart")
	if not rootPart then
		warn("ViewModelController: model", config.viewModelName, "has no RootPart")
		return
	end
	rootPart.Anchored = true  -- prevent physics from displacing the viewmodel between RenderStepped calls

	-- Auto-compute ADS offset from SightPoint position
	local sightLocal    = getSightLocalPos(rootPart)
	computedAdsOffset   = CFrame.new(-sightLocal.X, -sightLocal.Y, -config.adsDistance)

	-- Only cache gun-specific effects (muzzle flash, fire/reload sounds) for guns
	if config.isGun ~= false then
		muzzlePoint = activeModel:FindFirstChild("MuzzlePoint", true)
		if muzzlePoint then
			muzzleEmitter = muzzlePoint:FindFirstChildOfClass("ParticleEmitter")

			muzzleLights = {}

			for _, obj in ipairs(muzzlePoint:GetChildren()) do
				if obj:IsA("PointLight") or obj:IsA("SpotLight") then
					table.insert(muzzleLights, obj)
				end
			end

			-- disable all lights
			for _, light in ipairs(muzzleLights) do
				light.Enabled = false
			end
		else
			warn("ViewModelController:", config.viewModelName, "has no MuzzlePoint — muzzle flash and projectile spawn will use fallback")
		end
		fireSound   = activeModel:FindFirstChild("FireSound")
		reloadSound = activeModel:FindFirstChild("ReloadSound")
		emptySound  = activeModel:FindFirstChild("EmptySound")
	end

	local equipSound = activeModel:FindFirstChild("EquipSound")
	if equipSound then equipSound:Play() end

	renderConnection = RunService.RenderStepped:Connect(function(dt)
		-- Self-heal: if the model was destroyed for any reason, re-create it next frame
		if not rootPart or rootPart.Parent == nil then
			if activeConfig then
				local config = activeConfig
				local wasADS = isADS
				ViewModelController.show(config)
				isADS = wasADS
			end
			return
		end

		-- Equip raise animation
		equipProgress = math.clamp(equipProgress + dt / activeConfig.equipTime, 0, 1)
		local equipLerp = activeConfig.equipOffset:Lerp(CFrame.new(), equipProgress)

		-- ADS lerp
		local target = isADS and 1 or 0
		local step   = dt / activeConfig.adsSpeed
		adsProgress  = math.clamp(adsProgress + math.sign(target - adsProgress) * step, 0, 1)

		-- Recoil recovery
		recoilOffset = recoilOffset:Lerp(CFrame.new(), dt * activeConfig.recoilRecovery)

		-- Melee swing animation (procedural CFrame arc)
		if swingTime >= 0 then
			local alpha = swingTime / swingDuration
			if alpha <= 0.3 then
				-- Wind-up: rotate arms back and to the side
				local t = alpha / 0.3
				swingOffset = CFrame.Angles(math.rad(-25 * t), math.rad(10 * t), 0)
			elseif alpha <= 0.6 then
				-- Slash: rotate forward and down
				local t = (alpha - 0.3) / 0.3
				swingOffset = CFrame.Angles(math.rad(-25 + 60 * t), math.rad(10 - 30 * t), 0)
			else
				-- Recovery: lerp back to identity
				local t = (alpha - 0.6) / 0.4
				swingOffset = swingOffset:Lerp(CFrame.new(), t)
			end
			swingTime += dt
			if swingTime > swingDuration then
				swingTime = -1
				swingOffset = CFrame.new()
			end
		end

		local baseOffset = activeConfig.hipOffset:Lerp(computedAdsOffset, adsProgress)
		rootPart.CFrame  = workspace.CurrentCamera.CFrame * baseOffset * recoilOffset * swingOffset * equipLerp

		if muzzlePoint then
			muzzleWorldPos = muzzlePoint:IsA("Attachment") and muzzlePoint.WorldPosition or muzzlePoint.Position
		end

	end)
end

-- Called by GunHandler each time a shot is fired
function ViewModelController.onFire()
	if not activeConfig then return end

	-- Snap recoil to kick position (accumulates slightly if firing fast)
	local kickBack = CFrame.new(0, 0, activeConfig.recoilKick)
	local kickRot  = CFrame.Angles(-math.rad(activeConfig.recoilRotation), 0, 0)
	recoilOffset   = kickBack * kickRot

	if muzzleEmitter then
		muzzleEmitter:Emit(6)
	end

	if #muzzleLights > 0 then
		for _, light in ipairs(muzzleLights) do
			light.Enabled = true
		end

		task.delay(0.05, function()
			for _, light in ipairs(muzzleLights) do
				if light then
					light.Enabled = false
				end
			end
		end)
	end

	if fireSound then
		fireSound:Play()
	end
end

-- Called by GunHandler when a reload begins
function ViewModelController.onReload()
	if reloadSound then
		reloadSound:Play()
	end
end

-- Called by GunHandler when the player tries to fire with empty mag
function ViewModelController.onEmpty()
	if emptySound then
		emptySound:Play()
	end
end

-- Called by MeleeHandler each time the player swings
function ViewModelController.onSwing(config)
	swingDuration = config.swingDuration or 0.4
	swingTime = 0
	swingOffset = CFrame.new()
end

function ViewModelController.getActiveModel()
	return activeModel
end

function ViewModelController.getMuzzlePosition()
	return muzzleWorldPos
end

function ViewModelController.getAdsProgress()
	return adsProgress
end

function ViewModelController.setADS(active)
	isADS = active
end

function ViewModelController.hide()
	destroyActive()
	-- Clear config so the camera-replacement handler knows not to re-show
	activeConfig = nil
	isADS = false
end

return ViewModelController
