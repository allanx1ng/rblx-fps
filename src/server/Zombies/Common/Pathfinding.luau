local PathfindingService = game:GetService("PathfindingService")

local Module = {}

function Module.Initialize(zombieModel)
	local zombie = zombieModel
	local humanoid = zombie:FindFirstChild("Zombie")
	local rootPart = zombie:FindFirstChild("HumanoidRootPart")

	-- CRITICAL FIX: Force the server to keep control of the zombie's physics.
	-- This prevents the zombie from freezing when a player gets close to it.
	if rootPart and rootPart:CanSetNetworkOwnership() then
		rootPart:SetNetworkOwner(nil)
	end

	local function findNearestTorso(pos)
		local list = workspace:GetChildren()
		local torso = nil
		local dist = 10000

		for _, temp2 in pairs(list) do
			if temp2:IsA("Model") and temp2 ~= zombie then
				local tempRoot = temp2:FindFirstChild("HumanoidRootPart")
				local human = temp2:FindFirstChild("Humanoid")

				if tempRoot and human and human.Health > 0 then
					local currentDist = (tempRoot.Position - pos).Magnitude
					if currentDist < dist then
						torso = tempRoot
						dist = currentDist
					end
				end
			end
		end
		return torso
	end

	task.spawn(function()
		while true do
			-- A tiny task.wait() prevents crashing but runs instantly.
			task.wait()

			if rootPart and humanoid then
				local target = findNearestTorso(rootPart.Position)

				if target then
					-- Save the target's position exactly when we start calculating
					local targetPosWhenCalculated = target.Position

					local path = PathfindingService:CreatePath({
						AgentRadius = 2,
						AgentHeight = 5,
						AgentCanJump = true,
					})

					local success, errorMessage = pcall(function()
						path:ComputeAsync(rootPart.Position, targetPosWhenCalculated)
					end)

					if success and path.Status == Enum.PathStatus.Success then
						local waypoints = path:GetWaypoints()

						for i, waypoint in ipairs(waypoints) do
							if i == 1 then continue end

							if waypoint.Action == Enum.PathWaypointAction.Jump then
								humanoid.Jump = true
							end

							humanoid:MoveTo(waypoint.Position)

							-- Wait until the zombie reaches the waypoint
							humanoid.MoveToFinished:Wait(1)

							-- SMART RECALCULATION:
							-- If the player moves more than 5 studs away from where they were when
							-- we calculated the path, break the loop to calculate a new one.
							local distanceTargetMoved = (target.Position - targetPosWhenCalculated).Magnitude
							if distanceTargetMoved > 5 then
								break -- Target moved too far, time for a new path!
							end
						end
					else
						-- Fallback if pathfinding fails
						humanoid:MoveTo(target.Position)
						task.wait(0.1)
					end
				end
			end
		end
	end)
end

return Module
