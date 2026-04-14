local Players = game:GetService("Players")

local localUserId = Players.LocalPlayer.UserId

workspace.ChildAdded:Connect(function(child)
	if child.Name ~= "Projectile" then return end
	if child:GetAttribute("ShooterUserId") == localUserId then
		-- Don't hide explosive projectiles — server-only, shooter needs to see them
		if child:GetAttribute("Explosive") then return end

		child.Transparency = 1
		-- Hide any lights so they don't double up with the local cosmetic projectile
		for _, obj in child:GetChildren() do
			if obj:IsA("PointLight") or obj:IsA("SpotLight") then
				obj.Enabled = false
			end
		end
	end
end)

return true
