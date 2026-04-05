local Module = {}

local Players = game:GetService("Players")

local ATTACK_RANGE = 2
local ATTACK_COOLDOWN = 1.5

function Module.Initialize(zombieModel)
	local humanoid = zombieModel:WaitForChild("Zombie")
	local rootPart = zombieModel:WaitForChild("HumanoidRootPart")
	local damage = zombieModel:GetAttribute("Damage") or 10
	local alive = true
	local lastAttackTime = {} -- per-player cooldown

	-- Replace Motor6Ds with WeldConstraints so the body stays connected on death
	humanoid.Died:Connect(function()
		alive = false

		-- Swap joints to welds so limbs don't detach
		for _, motor in zombieModel:GetDescendants() do
			if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = motor.Part0
				weld.Part1 = motor.Part1
				weld.Parent = motor.Parent
				motor:Destroy()
			end
		end

		-- Disable collision so corpse doesn't block players
		for _, part in zombieModel:GetDescendants() do
			if part:IsA("BasePart") then
				-- part.CanCollide = false
			end
		end

		-- Keep the root collidable so the body rests on the ground
		rootPart.CanCollide = true

		-- Fade out after 3 seconds, then destroy
		task.delay(3, function()
			if not zombieModel.Parent then return end

			-- Gradually fade all parts over 2 seconds
			local FADE_TIME = 2
			local STEPS = 10
			for i = 1, STEPS do
				for _, part in zombieModel:GetDescendants() do
					if part:IsA("BasePart") then
						part.Transparency = i / STEPS
					end
				end
				task.wait(FADE_TIME / STEPS)
			end

			if zombieModel.Parent then
				zombieModel:Destroy()
			end
		end)
	end)

	task.spawn(function()
		while alive do
			task.wait(0.5)

			for _, player in Players:GetPlayers() do
				local character = player.Character
				if not character then continue end
				local playerRoot = character:FindFirstChild("HumanoidRootPart")
				local playerHumanoid = character:FindFirstChild("Humanoid")
				if not playerRoot or not playerHumanoid or playerHumanoid.Health <= 0 then continue end

				local dist = (rootPart.Position - playerRoot.Position).Magnitude
				if dist <= ATTACK_RANGE then
					local now = tick()
					if not lastAttackTime[player] or (now - lastAttackTime[player]) >= ATTACK_COOLDOWN then
						playerHumanoid:TakeDamage(damage)
						lastAttackTime[player] = now
					end
				end
			end
		end
	end)
end

return Module
