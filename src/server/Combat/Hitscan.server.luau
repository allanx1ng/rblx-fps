-- DealDamage remote handler — server-authoritative hitscan damage.
-- Client raycasts and reports the hit; server validates distance, friendly fire,
-- and applies damage with body-part multipliers and pierce falloff.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DamageUtil = require(script.Parent:WaitForChild("DamageUtil"))
local Guns = ReplicatedStorage.Shared.Guns

ReplicatedStorage.Remotes.DealDamage.OnServerEvent:Connect(function(shooter, hitPart, pierceMult)
	if not hitPart or not hitPart:IsA("BasePart") then return end
	-- Clamp pierce multiplier to valid range (untrusted client data)
	if type(pierceMult) ~= "number" then pierceMult = 1 end
	pierceMult = math.clamp(pierceMult, 0, 1)

	local victimCharacter = hitPart:FindFirstAncestorOfClass("Model")
	if not victimCharacter then return end

	local humanoid = victimCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- No friendly fire — only damage NPCs, not players
	if Players:GetPlayerFromCharacter(victimCharacter) then return end

	local shooterCharacter = shooter.Character
	if not shooterCharacter then return end
	local shooterHRP = shooterCharacter:FindFirstChild("HumanoidRootPart")
	local victimHRP  = victimCharacter:FindFirstChild("HumanoidRootPart")
	if not shooterHRP or not victimHRP then return end

	local tool = shooterCharacter:FindFirstChildOfClass("Tool")
	if not tool then return end

	local configModule = Guns:FindFirstChild(tool.Name)
	if not configModule then return end
	local config = require(configModule)

	-- Distance sanity check with generous latency tolerance
	local distance = (shooterHRP.Position - victimHRP.Position).Magnitude
	if distance > (config.range or 500) * 1.5 then return end

	-- Track who last damaged this zombie (for kill rewards)
	victimCharacter:SetAttribute("_LastDamagerUserId", shooter.UserId)

	local damage = config.damage * DamageUtil.getMultiplier(hitPart.Name, config) * pierceMult
	humanoid:TakeDamage(damage)
end)
