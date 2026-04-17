--[[
	FlickeringLights — makes tagged light sources flicker on independent
	per-light timers for a horror atmosphere.

	Tag a Light instance (PointLight/SpotLight/SurfaceLight) OR a BasePart
	containing Lights with "FlickeringLight" via CollectionService.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "FlickeringLight"

local MIN_IDLE = 3.0      -- shortest wait between flicker bursts
local MAX_IDLE = 12.0     -- longest wait between flicker bursts
local MIN_FLICKERS = 2    -- min rapid on/off toggles in one burst
local MAX_FLICKERS = 6    -- max rapid on/off toggles in one burst
local MIN_TOGGLE = 0.03   -- shortest single on/off duration
local MAX_TOGGLE = 0.18   -- longest single on/off duration
local DIM_MIN = 0.2       -- lowest brightness multiplier during flicker
local DIM_MAX = 0.9       -- highest brightness multiplier during flicker

local function randRange(lo, hi)
	return lo + math.random() * (hi - lo)
end

local tracked = {}  -- [Light] = state

local function scheduleNextBurst(state)
	state.mode = "idle"
	state.nextAt = os.clock() + randRange(MIN_IDLE, MAX_IDLE)
	state.remainingToggles = 0
end

local function startBurst(state)
	state.mode = "burst"
	state.remainingToggles = math.random(MIN_FLICKERS, MAX_FLICKERS)
	state.nextAt = os.clock()
end

local function addLight(light)
	if tracked[light] then return end
	if not (light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight")) then
		return
	end
	local state = {
		light = light,
		baseBrightness = light.Brightness,
		baseEnabled = light.Enabled,
		mode = "idle",
		nextAt = os.clock() + randRange(0, MAX_IDLE),  -- stagger initial timings
		remainingToggles = 0,
	}
	tracked[light] = state

	light.Destroying:Connect(function()
		tracked[light] = nil
	end)
end

local function addFromInstance(inst)
	if inst:IsA("Light") then
		addLight(inst)
	else
		for _, desc in inst:GetDescendants() do
			if desc:IsA("Light") then
				addLight(desc)
			end
		end
		inst.DescendantAdded:Connect(function(desc)
			if desc:IsA("Light") then
				addLight(desc)
			end
		end)
	end
end

for _, inst in CollectionService:GetTagged(TAG) do
	addFromInstance(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(addFromInstance)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for light, state in tracked do
		if not light.Parent then
			tracked[light] = nil
		elseif now >= state.nextAt then
			if state.mode == "idle" then
				startBurst(state)
			else
				-- Toggle: alternate between dim/off and base brightness
				if light.Brightness == state.baseBrightness and light.Enabled == state.baseEnabled then
					if math.random() < 0.4 then
						light.Enabled = false
					else
						light.Brightness = state.baseBrightness * randRange(DIM_MIN, DIM_MAX)
					end
				else
					light.Enabled = state.baseEnabled
					light.Brightness = state.baseBrightness
				end
				state.remainingToggles -= 1
				if state.remainingToggles <= 0 then
					light.Enabled = state.baseEnabled
					light.Brightness = state.baseBrightness
					scheduleNextBurst(state)
				else
					state.nextAt = now + randRange(MIN_TOGGLE, MAX_TOGGLE)
				end
			end
		end
	end
end)

return true
