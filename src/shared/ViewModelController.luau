local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewModelController = {}

local activeModel    = nil
local activeConfig   = nil
local rootPart       = nil
local computedAdsOffset = CFrame.new()
local renderConnection  = nil
local adsProgress    = 0
local isADS          = false
local recoilOffset   = CFrame.new()
local equipProgress  = 1  -- 0 = just equipped (arms down), 1 = fully raised

-- Effect references, found after cloning
local muzzlePoint       = nil
local muzzleWorldPos    = nil  -- cached each RenderStepped to avoid physics-frame drift
local muzzleEmitter  = nil
local muzzleLight    = nil
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
	muzzlePoint     = nil
	muzzleWorldPos  = nil
	muzzleEmitter   = nil
	muzzleLight     = nil
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
	activeModel.Parent = workspace.CurrentCamera

	rootPart = activeModel:FindFirstChild("RootPart")
	if not rootPart then
		warn("ViewModelController: model", config.viewModelName, "has no RootPart")
		return
	end
	rootPart.Anchored = true  -- prevent physics from displacing the viewmodel between RenderStepped calls

	-- Auto-compute ADS offset from SightPoint position
	local sightLocal    = getSightLocalPos(rootPart)
	computedAdsOffset   = CFrame.new(-sightLocal.X, -sightLocal.Y, -config.adsDistance)

	-- Cache effect references (all optional — missing ones are silently skipped)
	muzzlePoint = activeModel:FindFirstChild("MuzzlePoint", true)
	if muzzlePoint then
		muzzleEmitter = muzzlePoint:FindFirstChildOfClass("ParticleEmitter")
		muzzleLight   = muzzlePoint:FindFirstChildOfClass("PointLight")
			or muzzlePoint:FindFirstChildOfClass("SpotLight")
		if muzzleLight then muzzleLight.Enabled = false end
	else
		warn("ViewModelController:", config.viewModelName, "has no MuzzlePoint — muzzle flash and projectile spawn will use fallback")
	end
	fireSound   = activeModel:FindFirstChild("FireSound")
	reloadSound = activeModel:FindFirstChild("ReloadSound")
	emptySound  = activeModel:FindFirstChild("EmptySound")

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

		local baseOffset = activeConfig.hipOffset:Lerp(computedAdsOffset, adsProgress)
		rootPart.CFrame  = workspace.CurrentCamera.CFrame * baseOffset * recoilOffset * equipLerp

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

	if muzzleLight then
		muzzleLight.Enabled = true
		task.delay(0.05, function()
			if muzzleLight then muzzleLight.Enabled = false end
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

function ViewModelController.getMuzzlePosition()
	return muzzleWorldPos
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
