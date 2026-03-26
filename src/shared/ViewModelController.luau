local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewModelController = {}

local camera = workspace.CurrentCamera
local activeModel = nil
local activeConfig = nil
local renderConnection = nil
local adsProgress = 0
local isADS = false

local function destroyActive()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if activeModel then
		activeModel:Destroy()
		activeModel = nil
	end
	activeConfig = nil
	adsProgress = 0
	isADS = false
end

function ViewModelController.show(config)
	destroyActive()

	if not config.viewModelName then return end

	local template = ReplicatedStorage.Shared:FindFirstChild(config.viewModelName)
	if not template then
		warn("ViewModelController: no model named", config.viewModelName, "in ReplicatedStorage.Shared")
		return
	end

	activeConfig = config
	activeModel = template:Clone()
	activeModel.Parent = camera

	local rootPart = activeModel:FindFirstChild("RootPart")
	if not rootPart then
		warn("ViewModelController: model", config.viewModelName, "has no RootPart")
		return
	end

	renderConnection = RunService.RenderStepped:Connect(function(dt)
		-- Lerp adsProgress toward 0 (hip) or 1 (ads) at a rate matching adsSpeed
		local target = isADS and 1 or 0
		local step = dt / activeConfig.adsSpeed
		adsProgress = math.clamp(adsProgress + math.sign(target - adsProgress) * step, 0, 1)

		local offset = activeConfig.hipOffset:Lerp(activeConfig.adsOffset, adsProgress)
		rootPart.CFrame = camera.CFrame * offset
	end)
end

-- Called by GunHandler whenever ADS state changes
function ViewModelController.setADS(active)
	isADS = active
end

function ViewModelController.hide()
	destroyActive()
end

return ViewModelController
