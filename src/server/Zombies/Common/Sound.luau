local Module = {}

function Module.Initialize(zombieModel)
	local Head = zombieModel:WaitForChild("Head")
	local moan  = Head:WaitForChild("Moan")
	local moan2 = Head:WaitForChild("Moan2")
	local moan3 = Head:WaitForChild("Moan3")
	local moan4 = Head:WaitForChild("Moan4")
	local _death = Head:WaitForChild("Death")

	-- Stagger start so multiple zombies don't all moan in sync
	task.spawn(function()
		task.wait(math.random() * 10)

		while true do
			moan:Play()
			task.wait(8)

			moan2:Play()
			task.wait(5)

			moan3:Play()
			task.wait(7)

			moan4:Play()
			task.wait(6)
		end
	end)
end

return Module
