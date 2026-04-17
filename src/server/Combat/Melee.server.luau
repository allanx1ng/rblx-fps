-- Melee remote handlers — swing animation playback and damage application.
--
-- MeleeSwing: client requests a swing → server rate-limits and replicates the
-- slash animation via the character's Animator (so all clients see it).
-- MeleeDamage: client reports a hit → server validates and applies damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DamageUtil = require(script.Parent:WaitForChild("DamageUtil"))
local Melee = ReplicatedStorage.Shared:WaitForChild("Melee")

local meleeSwingRemote = ReplicatedStorage.Remotes:WaitForChild("MeleeSwing")
local meleeDamageRemote = ReplicatedStorage.Remotes:WaitForChild("MeleeDamage")

local lastSwingTime = {} -- [player] -> tick

meleeSwingRemote.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then return end
	local configModule = Melee:FindFirstChild(tool.Name)
	if not configModule then return end
	local config = require(configModule)

	-- Rate limit
	local now = tick()
	local last = lastSwingTime[player] or 0
	if (now - last) < config.swingCooldown * 0.8 then return end
	lastSwingTime[player] = now

	-- Play slash animation on the character's Animator (replicates to all clients)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Load fresh each swing — tracks don't survive character respawn
	local anim = Instance.new("Animation")
	anim.AnimationId = config.slashAnimationId
	print("[MeleeSwing] Playing slash animation:", config.slashAnimationId, "on", player.Name)
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	track:Play()
end)

meleeDamageRemote.OnServerEvent:Connect(function(attacker, hitPart)
	if not hitPart or not hitPart:IsA("BasePart") then return end

	local victimCharacter = hitPart:FindFirstAncestorOfClass("Model")
	if not victimCharacter then return end
	local humanoid = victimCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- No friendly fire — only damage NPCs
	if Players:GetPlayerFromCharacter(victimCharacter) then return end

	local attackerCharacter = attacker.Character
	if not attackerCharacter then return end
	local attackerHRP = attackerCharacter:FindFirstChild("HumanoidRootPart")
	local victimHRP = victimCharacter:FindFirstChild("HumanoidRootPart")
	if not attackerHRP or not victimHRP then return end

	local tool = attackerCharacter:FindFirstChildOfClass("Tool")
	if not tool then return end
	local configModule = Melee:FindFirstChild(tool.Name)
	if not configModule then return end
	local config = require(configModule)

	local distance = (attackerHRP.Position - victimHRP.Position).Magnitude
	if distance > config.range * 1.5 then return end

	-- Track who last damaged this zombie (for kill rewards)
	victimCharacter:SetAttribute("_LastDamagerUserId", attacker.UserId)

	local damage = config.damage * DamageUtil.getMultiplier(hitPart.Name, config)
	humanoid:TakeDamage(damage)
end)

Players.PlayerRemoving:Connect(function(player)
	lastSwingTime[player] = nil
end)
