--[[
	Custom Animate — replaces the default R6 Animate script.
	Identical to default except: no idle animations.
	Standing = no animation playing, arms stay in weld pose.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Melee = ReplicatedStorage.Shared:WaitForChild("Melee")

local localPlayer = Players.LocalPlayer

local Figure = nil
local Humanoid = nil
local toolAnimTrack = nil -- separate track for toolnone so it doesn't conflict with locomotion

local pose = "Standing"

local currentAnim = ""
local currentAnimInstance = nil
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1.0

local animTable = {}
local animNames = {
	-- NO idle entry
	walk =  {{ id = "http://www.roblox.com/asset/?id=180426354", weight = 10 }},
	run =   {{ id = "run.xml", weight = 10 }},
	jump =  {{ id = "http://www.roblox.com/asset/?id=125750702", weight = 10 }},
	fall =  {{ id = "http://www.roblox.com/asset/?id=180436148", weight = 10 }},
	climb = {{ id = "http://www.roblox.com/asset/?id=180436334", weight = 10 }},
	sit =   {{ id = "http://www.roblox.com/asset/?id=178130996", weight = 10 }},
}

local jumpAnimTime = 0
local jumpAnimDuration = 0.3
local fallTransitionTime = 0.3

-- -------------------------------------------------------
-- Animation setup
-- -------------------------------------------------------
local function configureAnimationSet(name, fileList)
	if animTable[name] ~= nil then
		for _, connection in pairs(animTable[name].connections) do
			connection:Disconnect()
		end
	end
	animTable[name] = {}
	animTable[name].count = 0
	animTable[name].totalWeight = 0
	animTable[name].connections = {}

	for idx, anim in pairs(fileList) do
		animTable[name][idx] = {}
		animTable[name][idx].anim = Instance.new("Animation")
		animTable[name][idx].anim.Name = name
		animTable[name][idx].anim.AnimationId = anim.id
		animTable[name][idx].weight = anim.weight
		animTable[name].count = animTable[name].count + 1
		animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
	end
end

-- -------------------------------------------------------
-- Playback
-- -------------------------------------------------------
local function stopAllAnimations()
	local oldAnim = currentAnim
	currentAnim = ""
	currentAnimInstance = nil
	if currentAnimKeyframeHandler ~= nil then
		currentAnimKeyframeHandler:Disconnect()
	end
	if currentAnimTrack ~= nil then
		currentAnimTrack:Stop()
		currentAnimTrack:Destroy()
		currentAnimTrack = nil
	end
	return oldAnim
end

local function setAnimationSpeed(speed)
	if speed ~= currentAnimSpeed then
		currentAnimSpeed = speed
		if currentAnimTrack then
			currentAnimTrack:AdjustSpeed(currentAnimSpeed)
		end
	end
end

local function keyFrameReachedFunc(frameName)
	if frameName == "End" then
		local repeatAnim = currentAnim
		if repeatAnim == "" then return end
		local animSpeed = currentAnimSpeed
		-- re-play will be handled by playAnimation
		currentAnimInstance = nil
		currentAnim = ""
		-- force replay
		local function playAnimation(animName, transitionTime)
			if not animTable[animName] then return end
			local roll = math.random(1, animTable[animName].totalWeight)
			local idx = 1
			while roll > animTable[animName][idx].weight do
				roll = roll - animTable[animName][idx].weight
				idx = idx + 1
			end
			local anim = animTable[animName][idx].anim
			if currentAnimTrack ~= nil then
				currentAnimTrack:Stop(transitionTime)
				currentAnimTrack:Destroy()
			end
			currentAnimSpeed = 1.0
			currentAnimTrack = Humanoid:LoadAnimation(anim)
			currentAnimTrack.Priority = Enum.AnimationPriority.Core
			currentAnimTrack:Play(transitionTime)
			currentAnim = animName
			currentAnimInstance = anim
			if currentAnimKeyframeHandler ~= nil then
				currentAnimKeyframeHandler:Disconnect()
			end
			currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:Connect(keyFrameReachedFunc)
		end
		playAnimation(repeatAnim, 0.0)
		setAnimationSpeed(animSpeed)
	end
end

local function playAnimation(animName, transitionTime)
	if not animTable[animName] then return end

	local roll = math.random(1, animTable[animName].totalWeight)
	local idx = 1
	while roll > animTable[animName][idx].weight do
		roll = roll - animTable[animName][idx].weight
		idx = idx + 1
	end
	local anim = animTable[animName][idx].anim

	if anim ~= currentAnimInstance then
		if currentAnimTrack ~= nil then
			currentAnimTrack:Stop(transitionTime)
			currentAnimTrack:Destroy()
		end
		currentAnimSpeed = 1.0
		currentAnimTrack = Humanoid:LoadAnimation(anim)
		currentAnimTrack.Priority = Enum.AnimationPriority.Core
		currentAnimTrack:Play(transitionTime)
		currentAnim = animName
		currentAnimInstance = anim
		if currentAnimKeyframeHandler ~= nil then
			currentAnimKeyframeHandler:Disconnect()
		end
		currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:Connect(keyFrameReachedFunc)
	end
end

-- -------------------------------------------------------
-- State handlers
-- -------------------------------------------------------
local function getRigScale()
	return Figure:GetScale()
end

local function onRunning(speed)
	speed /= getRigScale()
	if speed > 0.01 then
		playAnimation("walk", 0.1)
		if currentAnimInstance and currentAnimInstance.AnimationId == "http://www.roblox.com/asset/?id=180426354" then
			setAnimationSpeed(speed / 14.5)
		end
		pose = "Running"
	else
		-- No idle — just stop
		if currentAnim ~= "" then
			stopAllAnimations()
		end
		pose = "Standing"
	end
end

local function onDied()
	pose = "Dead"
end

local function onJumping()
	playAnimation("jump", 0.1)
	jumpAnimTime = jumpAnimDuration
	pose = "Jumping"
end

local function onClimbing(speed)
	speed /= getRigScale()
	playAnimation("climb", 0.1)
	setAnimationSpeed(speed / 12.0)
	pose = "Climbing"
end

local function onGettingUp()
	pose = "GettingUp"
end

local function onFreeFall()
	if jumpAnimTime <= 0 then
		playAnimation("fall", fallTransitionTime)
	end
	pose = "FreeFall"
end

local function onFallingDown()
	pose = "FallingDown"
end

local function onSeated()
	playAnimation("sit", 0.5)
	pose = "Seated"
end

local function onPlatformStanding()
	pose = "PlatformStanding"
end

-- -------------------------------------------------------
-- Move loop (from default Animate)
-- -------------------------------------------------------
local lastTick = 0

local function move(time)
	local deltaTime = time - lastTick
	lastTick = time

	if jumpAnimTime > 0 then
		jumpAnimTime = jumpAnimTime - deltaTime
	end

	if pose == "FreeFall" and jumpAnimTime <= 0 then
		playAnimation("fall", fallTransitionTime)
	elseif pose == "Seated" then
		playAnimation("sit", 0.5)
	elseif pose == "Running" then
		playAnimation("walk", 0.1)
	elseif pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "PlatformStanding" then
		stopAllAnimations()
	end
end

-- -------------------------------------------------------
-- Character setup
-- -------------------------------------------------------
local function setupCharacter(character)
	Figure = character
	Humanoid = character:WaitForChild("Humanoid")
	-- Kill the default Animate script
	local defaultAnimate = character:FindFirstChild("Animate")
	if defaultAnimate then
		defaultAnimate:Destroy()
	end

	-- Stop any existing tracks from the default script
	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
			track:Destroy()
		end
	end

	-- Reset state
	currentAnim = ""
	currentAnimInstance = nil
	currentAnimTrack = nil
	currentAnimSpeed = 1.0
	pose = "Standing"
	jumpAnimTime = 0

	-- Load animations
	for name, fileList in pairs(animNames) do
		configureAnimationSet(name, fileList)
	end

	-- Connect humanoid events
	Humanoid.Died:Connect(onDied)
	Humanoid.Running:Connect(onRunning)
	Humanoid.Jumping:Connect(onJumping)
	Humanoid.Climbing:Connect(onClimbing)
	Humanoid.GettingUp:Connect(onGettingUp)
	Humanoid.FreeFalling:Connect(onFreeFall)
	Humanoid.FallingDown:Connect(onFallingDown)
	Humanoid.Seated:Connect(onSeated)
	Humanoid.PlatformStanding:Connect(onPlatformStanding)

	-- Melee tool hold animation — play toolnone when a melee tool is equipped
	character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then return end
		if not Melee:FindFirstChild(child.Name) then return end

		-- Play the default tool hold pose (right arm raised)
		local animator = Humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = Humanoid
		end

		local toolnoneAnim = Instance.new("Animation")
		toolnoneAnim.AnimationId = "http://www.roblox.com/asset/?id=182393478"
		toolAnimTrack = animator:LoadAnimation(toolnoneAnim)
		toolAnimTrack.Priority = Enum.AnimationPriority.Idle
		toolAnimTrack.Looped = true
		toolAnimTrack:Play()
	end)

	character.ChildRemoved:Connect(function(child)
		if not child:IsA("Tool") then return end
		if toolAnimTrack then
			toolAnimTrack:Stop()
			toolAnimTrack:Destroy()
			toolAnimTrack = nil
		end
	end)

	-- Main loop
	task.spawn(function()
		while Figure and Figure.Parent ~= nil do
			local _, time = task.wait(0.1)
			move(time)
		end
	end)
end

-- -------------------------------------------------------
-- Lifecycle
-- -------------------------------------------------------
localPlayer.CharacterAdded:Connect(function(character)
	task.wait(0.1)
	setupCharacter(character)
end)

if localPlayer.Character then
	setupCharacter(localPlayer.Character)
end

return true
