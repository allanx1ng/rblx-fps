-- Level-up notification — shows a brief animated banner when the player levels up.
--
-- Lives at: StarterGui > PersistentHUD > LevelUpIndicator (LocalScript)
--
-- Listens for the LevelUp remote event from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LevelUpRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LevelUp")
local screenGui = script.Parent

local HOLD_DURATION = 2
local FADE_IN_TIME = 0.3
local FADE_OUT_TIME = 0.8

local function showLevelUp(newLevel)
	-- CanvasGroup supports GroupTransparency for fading all children at once
	local canvas = Instance.new("CanvasGroup")
	canvas.Name = "LevelUpNotification"
	canvas.Size = UDim2.new(0, 300, 0, 60)
	canvas.Position = UDim2.new(0.5, -150, 0.15, 0)
	canvas.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	canvas.BackgroundTransparency = 0.3
	canvas.BorderSizePixel = 0
	canvas.GroupTransparency = 1
	canvas.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = canvas

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 2
	stroke.Parent = canvas

	local label = Instance.new("TextLabel")
	label.Name = "LevelText"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "Level Up!  Lv. " .. newLevel
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = canvas

	local maxTextSize = Instance.new("UITextSizeConstraint")
	maxTextSize.MaxTextSize = 28
	maxTextSize.Parent = label

	-- Fade in
	local fadeIn = TweenService:Create(canvas, TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
	})
	fadeIn:Play()
	fadeIn.Completed:Wait()

	-- Hold
	task.wait(HOLD_DURATION)

	-- Fade out + slide up
	local fadeOut = TweenService:Create(canvas, TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		GroupTransparency = 1,
		Position = UDim2.new(0.5, -150, 0.12, 0),
	})
	fadeOut:Play()
	fadeOut.Completed:Wait()

	canvas:Destroy()
end

LevelUpRemote.OnClientEvent:Connect(function(newLevel)
	task.spawn(showLevelUp, newLevel)
end)
