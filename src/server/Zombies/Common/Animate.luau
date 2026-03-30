local Module = {}

local animNames = {
	idle = 	{
				{ id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
				{ id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
				{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 }
			},
	walk = 	{
				{ id = "http://www.roblox.com/asset/?id=507777826", weight = 10 }
			},
	run = 	{
				{ id = "http://www.roblox.com/asset/?id=507767714", weight = 10 }
			},
	swim = 	{
				{ id = "http://www.roblox.com/asset/?id=507784897", weight = 10 }
			},
	swimidle = 	{
				{ id = "http://www.roblox.com/asset/?id=507785072", weight = 10 }
			},
	jump = 	{
				{ id = "http://www.roblox.com/asset/?id=507765000", weight = 10 }
			},
	fall = 	{
				{ id = "http://www.roblox.com/asset/?id=507767968", weight = 10 }
			},
	climb = {
				{ id = "http://www.roblox.com/asset/?id=507765644", weight = 10 }
			},
	sit = 	{
				{ id = "http://www.roblox.com/asset/?id=507768133", weight = 10 }
			},
	toolnone = {
				{ id = "http://www.roblox.com/asset/?id=507768375", weight = 10 }
			},
	toolslash = {
				{ id = "http://www.roblox.com/asset/?id=507768375", weight = 10 }
			},
	toollunge = {
				{ id = "http://www.roblox.com/asset/?id=507768375", weight = 10 }
			},
	wave = {
				{ id = "http://www.roblox.com/asset/?id=507770239", weight = 10 }
			},
	point = {
				{ id = "http://www.roblox.com/asset/?id=507770453", weight = 10 }
			},
	dance = {
				{ id = "http://www.roblox.com/asset/?id=507771019", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=507771955", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=507772104", weight = 10 }
			},
	dance2 = {
				{ id = "http://www.roblox.com/asset/?id=507776043", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=507776720", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=507776879", weight = 10 }
			},
	dance3 = {
				{ id = "http://www.roblox.com/asset/?id=507777268", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=507777451", weight = 10 },
				{ id = "http://www.roblox.com/asset/?id=507777623", weight = 10 }
			},
	laugh = {
				{ id = "http://www.roblox.com/asset/?id=507770818", weight = 10 }
			},
	cheer = {
				{ id = "http://www.roblox.com/asset/?id=507770677", weight = 10 }
			},
}

-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
local emoteNames = { wave = false, point = false, dance = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

function Module.Initialize(zombieModel)
	local Figure = zombieModel
	local Humanoid = Figure:WaitForChild("Zombie")
	local pose = "Standing"

	local currentAnim = ""
	local currentAnimInstance = nil
	local currentAnimTrack = nil
	local currentAnimKeyframeHandler = nil
	local currentAnimSpeed = 1.0
	local animTable = {}

	math.randomseed(tick())

	local function configureAnimationSet(name, fileList)
		if (animTable[name] ~= nil) then
			for _, connection in pairs(animTable[name].connections) do
				connection:Disconnect()
			end
		end
		animTable[name] = {}
		animTable[name].count = 0
		animTable[name].totalWeight = 0
		animTable[name].connections = {}

		-- fallback to defaults
		if (animTable[name].count <= 0) then
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
	end

	for name, fileList in pairs(animNames) do
		configureAnimationSet(name, fileList)
	end

	-- ANIMATION

	-- declarations
	local toolAnim = "None"
	local toolAnimTime = 0

	local jumpAnimTime = 0
	local jumpAnimDuration = 0.31

	local toolTransitionTime = 0.1
	local fallTransitionTime = 0.2

	-- forward declarations
	local playAnimation
	local setAnimationSpeed

	-- functions

	local function stopAllAnimations()
		local oldAnim = currentAnim

		-- return to idle if finishing an emote
		if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
			oldAnim = "idle"
		end

		currentAnim = ""
		currentAnimInstance = nil
		if (currentAnimKeyframeHandler ~= nil) then
			currentAnimKeyframeHandler:Disconnect()
		end

		if (currentAnimTrack ~= nil) then
			currentAnimTrack:Stop()
			currentAnimTrack:Destroy()
			currentAnimTrack = nil
		end
		return oldAnim
	end

	setAnimationSpeed = function(speed)
		if speed ~= currentAnimSpeed then
			currentAnimSpeed = speed
			currentAnimTrack:AdjustSpeed(currentAnimSpeed)
		end
	end

	local function keyFrameReachedFunc(frameName)
		if (frameName == "End") then
			local repeatAnim = currentAnim
			-- return to idle if finishing an emote
			if (emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false) then
				repeatAnim = "idle"
			end

			local animSpeed = currentAnimSpeed
			playAnimation(repeatAnim, 0.15, Humanoid)
			setAnimationSpeed(animSpeed)
		end
	end

	-- Preload animations
	playAnimation = function(animName, transitionTime, humanoid)

		local roll = math.random(1, animTable[animName].totalWeight)
		local _origRoll = roll
		local idx = 1
		while (roll > animTable[animName][idx].weight) do
			roll = roll - animTable[animName][idx].weight
			idx = idx + 1
		end

		local anim = animTable[animName][idx].anim

		-- switch animation
		if (anim ~= currentAnimInstance) then

			if (currentAnimTrack ~= nil) then
				currentAnimTrack:Stop(transitionTime)
				currentAnimTrack:Destroy()
			end

			currentAnimSpeed = 1.0

			-- load it to the humanoid; get AnimationTrack
			currentAnimTrack = humanoid:LoadAnimation(anim)

			-- play the animation
			currentAnimTrack:Play(transitionTime)
			currentAnim = animName
			currentAnimInstance = anim

			-- set up keyframe name triggers
			if (currentAnimKeyframeHandler ~= nil) then
				currentAnimKeyframeHandler:Disconnect()
			end
			currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:Connect(keyFrameReachedFunc)
		end
	end

	-------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------

	local toolAnimName = ""
	local toolAnimTrack = nil
	local toolAnimInstance = nil
	local currentToolAnimKeyframeHandler = nil

	-- forward declaration
	local playToolAnimation

	local function toolKeyFrameReachedFunc(frameName)
		if (frameName == "End") then
			playToolAnimation(toolAnimName, 0.0, Humanoid)
		end
	end

	playToolAnimation = function(animName, transitionTime, humanoid)

		local roll = math.random(1, animTable[animName].totalWeight)
		local _origRoll = roll
		local idx = 1
		while (roll > animTable[animName][idx].weight) do
			roll = roll - animTable[animName][idx].weight
			idx = idx + 1
		end
		local anim = animTable[animName][idx].anim

		if (toolAnimInstance ~= anim) then

			if (toolAnimTrack ~= nil) then
				toolAnimTrack:Stop()
				toolAnimTrack:Destroy()
				transitionTime = 0
			end

			-- load it to the humanoid; get AnimationTrack
			toolAnimTrack = humanoid:LoadAnimation(anim)

			-- play the animation
			toolAnimTrack:Play(transitionTime)
			toolAnimName = animName
			toolAnimInstance = anim

			currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:Connect(toolKeyFrameReachedFunc)
		end
	end

	local function stopToolAnimations()
		local oldAnim = toolAnimName

		if (currentToolAnimKeyframeHandler ~= nil) then
			currentToolAnimKeyframeHandler:Disconnect()
		end

		toolAnimName = ""
		toolAnimInstance = nil
		if (toolAnimTrack ~= nil) then
			toolAnimTrack:Stop()
			toolAnimTrack:Destroy()
			toolAnimTrack = nil
		end

		return oldAnim
	end

	-------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------

	local function onRunning(speed)
		if speed > 0.01 then
			local scale = 15.0
			playAnimation("walk", 0.1, Humanoid)
			setAnimationSpeed(speed / scale)
			pose = "Running"
		else
			playAnimation("idle", 0.1, Humanoid)
			pose = "Standing"
		end
	end

	local function onDied()
		pose = "Dead"
	end

	local function onJumping()
		playAnimation("jump", 0.1, Humanoid)
		jumpAnimTime = jumpAnimDuration
		pose = "Jumping"
	end

	local function onClimbing(speed)
		local scale = 5.0
		playAnimation("climb", 0.1, Humanoid)
		setAnimationSpeed(speed / scale)
		pose = "Climbing"
	end

	local function onGettingUp()
		pose = "GettingUp"
	end

	local function onFreeFall()
		if (jumpAnimTime <= 0) then
			playAnimation("fall", fallTransitionTime, Humanoid)
		end
		pose = "FreeFall"
	end

	local function onFallingDown()
		pose = "FallingDown"
	end

	local function onSeated()
		pose = "Seated"
	end

	local function onPlatformStanding()
		pose = "PlatformStanding"
	end

	local function onSwimming(speed)
		if speed > 1.00 then
			local scale = 10.0
			playAnimation("swim", 0.4, Humanoid)
			setAnimationSpeed(speed / scale)
			pose = "Swimming"
		else
			playAnimation("swimidle", 0.4, Humanoid)
			pose = "Standing"
		end
	end

	local function getTool()
		for _, kid in ipairs(Figure:GetChildren()) do
			if kid.className == "Tool" then return kid end
		end
		return nil
	end

	local function getToolAnim(tool)
		for _, c in ipairs(tool:GetChildren()) do
			if c.Name == "toolanim" and c.className == "StringValue" then
				return c
			end
		end
		return nil
	end

	local function animateTool()
		if (toolAnim == "None") then
			playToolAnimation("toolnone", toolTransitionTime, Humanoid)
			return
		end

		if (toolAnim == "Slash") then
			playToolAnimation("toolslash", 0, Humanoid)
			return
		end

		if (toolAnim == "Lunge") then
			playToolAnimation("toollunge", 0, Humanoid)
			return
		end
	end

	local lastTick = 0

	local function move(time)
		local deltaTime = time - lastTick
		lastTick = time

		if (jumpAnimTime > 0) then
			jumpAnimTime = jumpAnimTime - deltaTime
		end

		if (pose == "FreeFall" and jumpAnimTime <= 0) then
			playAnimation("fall", fallTransitionTime, Humanoid)
		elseif (pose == "Seated") then
			playAnimation("sit", 0.5, Humanoid)
			return
		elseif (pose == "Running") then
			playAnimation("walk", 0.1, Humanoid)
		elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "Seated" or pose == "PlatformStanding") then
			stopAllAnimations()
		end

		-- Tool Animation handling
		local tool = getTool()
		if tool then
			local animStringValueObject = getToolAnim(tool)

			if animStringValueObject then
				toolAnim = animStringValueObject.Value
				-- message recieved, delete StringValue
				animStringValueObject.Parent = nil
				toolAnimTime = time + .3
			end

			if time > toolAnimTime then
				toolAnimTime = 0
				toolAnim = "None"
			end

			animateTool()
		else
			stopToolAnimations()
			toolAnim = "None"
			toolAnimInstance = nil
			toolAnimTime = 0
		end
	end

	-- connect events
	Humanoid.Died:Connect(onDied)
	Humanoid.Running:Connect(onRunning)
	Humanoid.Jumping:Connect(onJumping)
	Humanoid.Climbing:Connect(onClimbing)
	Humanoid.GettingUp:Connect(onGettingUp)
	Humanoid.FreeFalling:Connect(onFreeFall)
	Humanoid.FallingDown:Connect(onFallingDown)
	Humanoid.Seated:Connect(onSeated)
	Humanoid.PlatformStanding:Connect(onPlatformStanding)
	Humanoid.Swimming:Connect(onSwimming)

	-- initialize to idle
	playAnimation("idle", 0.1, Humanoid)
	pose = "Standing"

	-- main loop
	task.spawn(function()
		while Figure.Parent ~= nil do
			local _, time = task.wait(0.1)
			move(time)
		end
	end)
end

return Module
