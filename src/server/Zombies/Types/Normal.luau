local Module = {}

function Module.Initialize(zombieModel)
	local humanoid = zombieModel:WaitForChild("Zombie")
	humanoid.WalkSpeed = zombieModel:GetAttribute("WalkSpeed") or 10
end

return Module
