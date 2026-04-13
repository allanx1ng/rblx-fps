-- Displays a 3D weapon model inside the CurrWeapon ViewportFrame on loadout pages.
--
-- Listens for weapon selection changes by polling the CurrWeapon panel's WeaponName
-- label. When it changes, clones the corresponding model from ReplicatedStorage.ViewModels
-- into the ViewportFrame with a dedicated camera, and slowly rotates it.
--
-- Requires a ViewportFrame named "WeaponViewport" inside each CurrWeapon frame (tagged "CurrWeapon").

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)

local lobbyUI = script:FindFirstAncestor("LobbyUI")
local viewModelsFolder = ReplicatedStorage:WaitForChild("ViewModels")

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function findTaggedDescendant(ancestor, tag)
	for _, child in ancestor:GetDescendants() do
		if CollectionService:HasTag(child, tag) then
			return child
		end
	end
	return nil
end

-- Build a lookup: weaponName -> config (for viewModelName)
local weaponConfigs = {}
local function ensureConfig(weaponName)
	if weaponConfigs[weaponName] then return weaponConfigs[weaponName] end
	local gunsFolder = ReplicatedStorage:FindFirstChild("Shared")
		and ReplicatedStorage.Shared:FindFirstChild("Guns")
	if gunsFolder then
		local configModule = gunsFolder:FindFirstChild(weaponName)
		if configModule then
			local ok, cfg = pcall(require, configModule)
			if ok then
				weaponConfigs[weaponName] = cfg
				return cfg
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Get the bounding box of a model (all BaseParts)
-- ---------------------------------------------------------------------------
local function getModelBounds(model)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local cf = part.CFrame
			local size = part.Size / 2
			-- 8 corners of the part's bounding box
			for _, corner in {
				Vector3.new(1,1,1), Vector3.new(1,1,-1),
				Vector3.new(1,-1,1), Vector3.new(1,-1,-1),
				Vector3.new(-1,1,1), Vector3.new(-1,1,-1),
				Vector3.new(-1,-1,1), Vector3.new(-1,-1,-1),
			} do
				local world = cf:PointToWorldSpace(size * corner)
				min = Vector3.new(math.min(min.X, world.X), math.min(min.Y, world.Y), math.min(min.Z, world.Z))
				max = Vector3.new(math.max(max.X, world.X), math.max(max.Y, world.Y), math.max(max.Z, world.Z))
			end
		end
	end

	local center = (min + max) / 2
	local extents = max - min
	return center, extents
end

-- ---------------------------------------------------------------------------
-- Per-viewport state
-- ---------------------------------------------------------------------------
type ViewportState = {
	viewport: ViewportFrame,
	camera: Camera,
	currentModel: Model?,
	currentWeaponName: string?,
	nameLabel: TextLabel?,
	spinAngle: number,
}

local viewportStates: { ViewportState } = {}

-- ---------------------------------------------------------------------------
-- Set up a viewport for a CurrWeapon frame
-- ---------------------------------------------------------------------------
local function setupViewport(currWeaponFrame): ViewportState?
	local viewport = currWeaponFrame:FindFirstChild("WeaponViewport")
	if not viewport or not viewport:IsA("ViewportFrame") then
		return nil
	end

	-- Create a dedicated camera for this viewport
	local cam = Instance.new("Camera")
	cam.FieldOfView = 50
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	local nameLabel = currWeaponFrame:FindFirstChild("WeaponName", true)

	return {
		viewport = viewport,
		camera = cam,
		currentModel = nil,
		currentWeaponName = nil,
		nameLabel = nameLabel,
		spinAngle = 0,
	}
end

-- ---------------------------------------------------------------------------
-- Display a weapon model in the viewport
-- ---------------------------------------------------------------------------
local function showWeapon(state: ViewportState, weaponName: string)
	if state.currentWeaponName == weaponName then return end
	state.currentWeaponName = weaponName

	-- Clear old model
	if state.currentModel then
		state.currentModel:Destroy()
		state.currentModel = nil
	end

	if not weaponName or weaponName == "" then
		return
	end

	-- Resolve viewModelName from config
	local config = ensureConfig(weaponName)
	local modelName = config and config.viewModelName or weaponName

	local template = viewModelsFolder:FindFirstChild(modelName)
	if not template then
		warn("[ViewportWeaponPreview] No model found:", modelName)
		return
	end

	local model = template:Clone()

	-- Strip scripts, sounds, particles, lights — we only want the visual mesh
	for _, desc in model:GetDescendants() do
		if desc:IsA("BaseScript") or desc:IsA("Sound") or desc:IsA("ParticleEmitter")
			or desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then
			desc:Destroy()
		end
	end

	-- Remove arms (parts named "Left Arm", "Right Arm") — we only want the gun
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			local n = desc.Name
			if n == "Left Arm" or n == "Right Arm" or n == "Torso" or n == "HumanoidRootPart" then
				desc:Destroy()
			end
		end
	end

	-- Remove Humanoid (not needed for viewport display)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Destroy() end

	-- Anchor all parts
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	-- Position model at origin
	local primaryPart = model:FindFirstChild("RootPart") or model.PrimaryPart
	if primaryPart then
		model:PivotTo(CFrame.new())
	end

	model.Parent = state.viewport
	state.currentModel = model
	state.spinAngle = 0

	-- Set initial camera position
	local center, extents = getModelBounds(model)
	local maxExtent = math.max(extents.X, extents.Y, extents.Z)
	local distance = maxExtent * 0.8 + 0.5

	state.camera.CFrame = CFrame.new(center + Vector3.new(0, maxExtent * 0.1, distance), center)
end

-- ---------------------------------------------------------------------------
-- Resolve weapon name from display name using WeaponRegistry
-- ---------------------------------------------------------------------------
local displayNameToName = {}
for _, slot in { "primary", "secondary", "melee" } do
	local weapons = WeaponRegistry[slot]
	if weapons then
		for _, entry in weapons do
			displayNameToName[entry.displayName] = entry.name
		end
	end
end

-- ---------------------------------------------------------------------------
-- Init — find all CurrWeapon panels and set up viewports
-- ---------------------------------------------------------------------------
local function init()
	for _, frame in CollectionService:GetTagged("CurrWeapon") do
		if frame:IsDescendantOf(lobbyUI) then
			local state = setupViewport(frame)
			if state then
				table.insert(viewportStates, state)
			end
		end
	end
end

init()

-- ---------------------------------------------------------------------------
-- Update loop — check for selection changes and rotate models
-- ---------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	for _, state in viewportStates do
		-- Check if the displayed weapon changed (by reading the WeaponName label)
		if state.nameLabel then
			local displayName = state.nameLabel.Text
			local weaponName = displayNameToName[displayName]
			if weaponName and weaponName ~= state.currentWeaponName then
				showWeapon(state, weaponName)
			end
		end

		-- Slowly rotate the model
		if state.currentModel then
			state.spinAngle = state.spinAngle + dt * 30 -- degrees per second

			local center, extents = getModelBounds(state.currentModel)
			local maxExtent = math.max(extents.X, extents.Y, extents.Z)
			local distance = maxExtent * 0.8 + 0.5

			local angleRad = math.rad(state.spinAngle)
			local camPos = center + Vector3.new(
				math.sin(angleRad) * distance,
				maxExtent * 0.1,
				math.cos(angleRad) * distance
			)
			state.camera.CFrame = CFrame.new(camPos, center)
		end
	end
end)
