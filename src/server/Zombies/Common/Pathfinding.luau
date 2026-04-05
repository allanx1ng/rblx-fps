local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

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

	local function findNearestPlayer(pos)
		local nearest = nil
		local nearestDist = math.huge
		for _, player in Players:GetPlayers() do
			local char = player.Character
			if not char then continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChild("Humanoid")
			if not hrp or not hum or hum.Health <= 0 then continue end
			local dist = (hrp.Position - pos).Magnitude
			if dist < nearestDist then
				nearest = hrp
				nearestDist = dist
			end
		end
		return nearest
	end

	-- Reuse a single Path object instead of creating one every iteration
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})

	task.spawn(function()
		while true do
			task.wait()

			if rootPart and humanoid then
				local target = findNearestPlayer(rootPart.Position)

				if target then
					local targetPosWhenCalculated = target.Position

					-- Move toward target while computing so the zombie never idles
					humanoid:MoveTo(targetPosWhenCalculated)

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
