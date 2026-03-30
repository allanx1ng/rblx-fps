local Module = {}

function Module.Initialize(zombieModel)
	local humanoid = zombieModel:WaitForChild("Zombie")
	humanoid.WalkSpeed = zombieModel:GetAttribute("WalkSpeed") or 18
end

return Module
