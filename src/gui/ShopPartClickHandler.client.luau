-- Detects clicks on shop parts in the lobby and opens the same purchase
-- popup that the loadout page uses.
--
-- Lives inside LobbyUI as a sibling of WeaponListBuilder and
-- PurchasePopupController so it has direct access to the RequestPurchase
-- BindableEvent.
--
-- A "shop part" is any BasePart in Workspace with a String attribute
-- "ItemName" whose value matches a registry entry name.
--
-- Cursor: when hovering a shop part, an invisible TextButton is positioned
-- under the cursor. Because Roblox automatically swaps the cursor on hover
-- of a GuiButton, this gives us the same cursor it uses for any other
-- clickable UI without needing a custom asset id. Clicking the button fires
-- the popup.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)
local ItemRegistry   = require(ReplicatedStorage.Shared.ItemRegistry)
local BuffRegistry   = require(ReplicatedStorage.Shared.BuffRegistry)

print("[ShopPartClick] loaded")

local player    = Players.LocalPlayer
local mouse     = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")
local lobbyUI   = script:FindFirstAncestor("LobbyUI")

local function isShopPart(target: Instance?): boolean
	if not target or not target:IsA("BasePart") then return false end
	local itemName = target:GetAttribute("ItemName")
	return type(itemName) == "string" and itemName ~= ""
end

local function isOwned(itemName: string): boolean
	return player:GetAttribute("Unlocked_" .. itemName) == true
end

-- ---------------------------------------------------------------------------
-- BillboardGui ownership state — patches the server-created BillboardGui
-- locally to show "Owned" when the player has unlocked the item.
-- ---------------------------------------------------------------------------
local trackedParts: { [BasePart]: boolean } = {}

local function refreshBillboard(part: BasePart)
	local itemName = part:GetAttribute("ItemName")
	if type(itemName) ~= "string" then return end

	local bb = part:FindFirstChild("ShopPartBillboard")
	if not bb then return end
	local priceFrame = bb:FindFirstChild("PriceDisplay")
	if not priceFrame then return end
	local priceText = priceFrame:FindFirstChild("PriceText") :: TextLabel?
	local icon      = priceFrame:FindFirstChild("CurrencyIcon") :: ImageLabel?
	if not priceText then return end

	if isOwned(itemName) then
		priceText.Text = "[Owned]"
		priceText.TextColor3 = Color3.fromRGB(120, 255, 120)
		if icon then icon.Visible = false end
	end
end

local function trackPart(part: Instance)
	if not part:IsA("BasePart") then return end
	if part:GetAttribute("ItemName") == nil then return end
	if trackedParts[part :: BasePart] then return end
	trackedParts[part :: BasePart] = true

	-- BillboardGui may not have replicated yet — try now and again on ChildAdded
	refreshBillboard(part :: BasePart)
	part.ChildAdded:Connect(function(child)
		if child.Name == "ShopPartBillboard" then
			refreshBillboard(part :: BasePart)
		end
	end)
end

for _, d in Workspace:GetDescendants() do
	trackPart(d)
end
Workspace.DescendantAdded:Connect(trackPart)

player.AttributeChanged:Connect(function(attr)
	if not string.find(attr, "^Unlocked_") then return end
	for part in trackedParts do
		refreshBillboard(part)
	end
end)

local function findEntry(itemName: string)
	for _, weapons in WeaponRegistry do
		for _, w in weapons do
			if w.name == itemName then return w end
		end
	end
	for _, item in ItemRegistry do
		if item.name == itemName then return item end
	end
	for _, buff in BuffRegistry do
		if buff.name == itemName then return buff end
	end
	return nil
end

local function openPopupFor(part: BasePart)
	local itemName = part:GetAttribute("ItemName")
	if type(itemName) ~= "string" or itemName == "" then return end

	if isOwned(itemName) then
		print("[ShopPartClick] ignoring click — already owned:", itemName)
		return
	end

	local entry = findEntry(itemName)
	if not entry then
		warn("[ShopPartClick] no registry entry named", itemName)
		return
	end

	local popupEvent = lobbyUI:WaitForChild("RequestPurchase", 5)
	if not popupEvent then
		warn("[ShopPartClick] RequestPurchase BindableEvent not found in LobbyUI")
		return
	end

	print("[ShopPartClick] firing RequestPurchase for", entry.displayName or entry.name)
	popupEvent:Fire(entry)
end

-- ---------------------------------------------------------------------------
-- Invisible hover button — sits under the cursor whenever it's over a shop
-- part. Roblox auto-swaps the cursor on GuiButton hover, so this gives us
-- the same cursor used elsewhere in the UI for free.
-- ---------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopPartHoverGui"
screenGui.ResetOnSpawn = false
-- IgnoreGuiInset stays FALSE so the gui's (0,0) matches mouse.X/Y, which are
-- reported relative to the topbar-excluded space.
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 50
screenGui.Parent = playerGui

local hoverButton = Instance.new("TextButton")
hoverButton.Name = "HoverButton"
hoverButton.BackgroundTransparency = 1
hoverButton.Text = ""
hoverButton.AutoButtonColor = false
hoverButton.Active = true
hoverButton.Selectable = false
hoverButton.Size = UDim2.fromOffset(80, 80)
hoverButton.AnchorPoint = Vector2.new(0.5, 0.5)
hoverButton.Position = UDim2.fromOffset(-1000, -1000)
hoverButton.Visible = false
hoverButton.Parent = screenGui

local currentTarget: BasePart? = nil

hoverButton.Activated:Connect(function()
	if currentTarget then
		openPopupFor(currentTarget)
	end
end)

-- Fallback: if for any reason the invisible button misses the click
-- (cursor moved between RenderStepped and the click, etc.), this guarantees
-- clicks on shop parts still work.
mouse.Button1Down:Connect(function()
	local target = mouse.Target
	if isShopPart(target) then
		openPopupFor(target :: BasePart)
	end
end)

RunService.RenderStepped:Connect(function()
	local target = mouse.Target
	if isShopPart(target) and not isOwned(target:GetAttribute("ItemName") :: string) then
		-- Lazily track parts we encounter via mouse target, in case the
		-- initial workspace scan missed them due to streaming.
		trackPart(target)
		currentTarget = target :: BasePart
		hoverButton.Position = UDim2.fromOffset(mouse.X, mouse.Y)
		hoverButton.Visible = true
	else
		currentTarget = nil
		hoverButton.Visible = false
	end
end)
