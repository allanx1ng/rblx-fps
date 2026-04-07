-- Server-side shop part controller.
--
-- Finds every BasePart in Workspace that has a string attribute "ItemName"
-- matching an entry in WeaponRegistry or ItemRegistry, anchors it, attaches
-- a floating BillboardGui with the item name + price, bobs it up and down,
-- and attaches a ClickDetector. When a player clicks, the server fires the
-- OpenShopPopup RemoteEvent at that player — the client listener in
-- ShopPartController then opens the purchase popup.
--
-- Setup per part:
--   • Parent the BasePart under Workspace.
--   • Add a String attribute "ItemName" whose value matches a registry name
--     (e.g. "AK47", "HealingPotion"). No CollectionService tag required.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)
local ItemRegistry   = require(ReplicatedStorage.Shared.ItemRegistry)


local BOB_HEIGHT = 0.5       -- studs of vertical travel from rest
local BOB_SPEED  = 2         -- radians/sec
local SPIN_SPEED = math.rad(45)

local COIN_ICON  = "rbxassetid://93087943622513"
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"

-- ---------------------------------------------------------------------------
-- Registry lookup
-- ---------------------------------------------------------------------------
local function findEntry(itemName: string)
	for _, weapons in WeaponRegistry do
		for _, w in weapons do
			if w.name == itemName then return w end
		end
	end
	for _, item in ItemRegistry do
		if item.name == itemName then return item end
	end
	return nil
end

local function formatNumber(n: number): string
	local formatted = tostring(math.floor(n))
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

-- ---------------------------------------------------------------------------
-- BillboardGui builder
-- ---------------------------------------------------------------------------
local function buildBillboard(part: BasePart, entry)
	local existing = part:FindFirstChild("ShopPartBillboard")
	if existing then existing:Destroy() end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShopPartBillboard"
	billboard.Adornee = part
	billboard.Size = UDim2.fromOffset(200, 70)
	-- Calculate vertical and forward offsets
	local partCFrame = part.CFrame
	local worldUp = Vector3.new(0, 1, 0)
	local offsetLocal = partCFrame:VectorToObjectSpace(worldUp) -- expresses world-up in part's local axes
	billboard.StudsOffsetWorldSpace = offsetLocal * (3)

	
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 150

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Text = entry.displayName or entry.name
	nameLabel.Parent = billboard

	local priceFrame = Instance.new("Frame")
	priceFrame.Name = "PriceDisplay"
	priceFrame.BackgroundTransparency = 1
	priceFrame.Size = UDim2.new(1, 0, 0.45, 0)
	priceFrame.Position = UDim2.new(0, 0, 0.55, 0)
	priceFrame.Parent = billboard

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = priceFrame

	local icon = Instance.new("ImageLabel")
	icon.Name = "CurrencyIcon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(24, 24)
	icon.LayoutOrder = 1
	icon.Parent = priceFrame
	icon.ScaleType = Enum.ScaleType.Crop

	local priceText = Instance.new("TextLabel")
	priceText.Name = "PriceText"
	priceText.BackgroundTransparency = 1
	priceText.Size = UDim2.fromOffset(24, 24)
	priceText.Font = Enum.Font.GothamBold
	-- priceText.TextScaled = true
	priceText.TextSize = 24
	priceText.TextXAlignment = Enum.TextXAlignment.Left
	priceText.TextColor3 = Color3.fromRGB(255, 215, 0)
	priceText.TextStrokeTransparency = 0
	priceText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	priceText.LayoutOrder = 2
	priceText.Parent = priceFrame
	priceText.AutomaticSize = Enum.AutomaticSize.X

	if (entry.robuxCost or 0) > 0 then
		icon.Image = ROBUX_ICON
		priceText.Text = formatNumber(entry.robuxCost)
		priceText.TextColor3 = Color3.fromRGB(120, 220, 255)
	else
		icon.Image = COIN_ICON
		priceText.Text = formatNumber(entry.unlockCost or 0)
	end

	billboard.Parent = part
	return billboard
end

-- ---------------------------------------------------------------------------
-- Per-part state
-- ---------------------------------------------------------------------------
type PartState = {
	part: BasePart,
	entry: any,
	restCFrame: CFrame,
	clickConn: RBXScriptConnection?,
}

local states: { [BasePart]: PartState } = {}
local startTime = os.clock()

local function teardownPart(inst: Instance)
	local state = states[inst :: BasePart]
	if not state then return end
	if state.clickConn then state.clickConn:Disconnect() end
	local bb = state.part:FindFirstChild("ShopPartBillboard")
	if bb then bb:Destroy() end
	states[state.part] = nil
end

local function setupPart(part: BasePart)
	if states[part] then return end

	local itemName = part:GetAttribute("ItemName")
	if type(itemName) ~= "string" or itemName == "" then return end

	local entry = findEntry(itemName)
	if not entry then
		warn(("[ShopParts] %s: no registry entry named %q"):format(part:GetFullName(), itemName))
		return
	end

	part.Anchored = true
	local restCFrame = part.CFrame

	buildBillboard(part, entry)

	-- The client (src/gui/ShopPartClickHandler.client.luau, parented to LobbyUI)
	-- detects clicks via Mouse:GetTarget() and reads the ItemName attribute
	-- directly. No ClickDetector or server communication needed for clicks.

	local state: PartState = {
		part = part,
		entry = entry,
		restCFrame = restCFrame,
		clickConn = nil,
	}

	states[part] = state
	print(("[ShopParts] attached %s → %s"):format(part:GetFullName(), entry.displayName or entry.name))
end

local function tryAttach(inst: Instance)
	if inst:IsA("BasePart") and inst:GetAttribute("ItemName") ~= nil then
		setupPart(inst)
	end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
for _, d in Workspace:GetDescendants() do
	tryAttach(d)
end
Workspace.DescendantAdded:Connect(tryAttach)
Workspace.DescendantRemoving:Connect(teardownPart)

print(("[ShopParts] server init complete — %d parts attached"):format(#(function()
	local t = {} for p in states do table.insert(t, p) end return t
end)()))

-- ---------------------------------------------------------------------------
-- Bob + spin animation
-- ---------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local t = os.clock() - startTime
	for _, state in states do
		local restPos = state.restCFrame.Position
		local phase = (restPos.X + restPos.Z) * 0.3
		local yOffset = math.sin(t * BOB_SPEED + phase) * BOB_HEIGHT

		-- Spin around the WORLD Y axis (not the part's local Y) so parts
		-- whose base orientation has X/Z rotation still spin upright.
		-- Decompose: keep the rest rotation as-is, pre-multiply it by a
		-- world-Y rotation, then translate to the bobbed world position.
		local restRot = state.restCFrame - restPos
		local worldSpin = CFrame.Angles(0, t * SPIN_SPEED, 0)
		state.part.CFrame = CFrame.new(restPos + Vector3.new(0, yOffset, 0)) * worldSpin * restRot
	end
end)
