-- Wires up the purchase confirmation popup for weapons, items, and buffs.
--
-- The popup lives in its own ScreenGui (PurchasePopupGui, DisplayOrder=100)
-- so it renders above all other UI and blocks input behind it.
--
-- The popup is opened via a BindableEvent "RequestPurchase" on LobbyUI.
-- Other scripts (e.g. WeaponListBuilder) fire it with the registry entry table.
--
-- The popup root is a full-screen TextButton tagged "PurchasePopup".
-- All children are found via FindFirstChild by name:
--
-- PurchasePopup (TextButton, tagged "PurchasePopup", full-screen, semi-transparent)
-- └── PopupFrame (Frame, centered)
--     ├── Title           — TextLabel
--     ├── ItemName        — TextLabel
--     ├── PriceDisplay    — Frame
--     │   ├── CurrencyIcon  — ImageLabel
--     │   └── PriceText     — TextLabel
--     ├── Message         — TextLabel (shown after result)
--     ├── ConfirmButton   — TextButton
--     ├── CancelButton    — TextButton
--     └── ExitButton      — TextButton (shown after result)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local lobbyUI = script:FindFirstAncestor("LobbyUI")

local PurchaseWeapon = ReplicatedStorage.Remotes.PurchaseWeapon
local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)

local COIN_ICON = "rbxassetid://93087943622513"
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function isInsideGui(guiObject, position)
	local absPos = guiObject.AbsolutePosition
	local absSize = guiObject.AbsoluteSize
	return position.X >= absPos.X
		and position.X <= absPos.X + absSize.X
		and position.Y >= absPos.Y
		and position.Y <= absPos.Y + absSize.Y
end

local function findTaggedDescendant(ancestor, tag)
	for _, child in ancestor:GetDescendants() do
		if CollectionService:HasTag(child, tag) then
			return child
		end
	end
	return nil
end

local function formatNumber(n)
	local formatted = tostring(math.floor(n))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

local function getEntryCost(entry)
	if (entry.robuxCost or 0) > 0 then
		return entry.robuxCost, "robux", ROBUX_ICON
	end
	return entry.unlockCost or 0, "gold", COIN_ICON
end

local function getCategoryLabel(entry)
	for slot, weapons in WeaponRegistry do
		for _, w in weapons do
			if w.name == entry.name then
				if slot == "primary" or slot == "secondary" or slot == "melee" then
					return "Purchase Weapon"
				end
			end
		end
	end
	return "Purchase Item"
end

-- ---------------------------------------------------------------------------
-- Find popup and resolve children
-- ---------------------------------------------------------------------------
local popup = nil
local popupFrame
local titleLabel, itemNameLabel, currencyIcon, priceText, priceDisplay
local messageLabel, confirmButton, cancelButton, exitButton

local function resolvePopupChildren(root)
	popupFrame    = root:FindFirstChild("PopupFrame") or root
	titleLabel    = popupFrame:FindFirstChild("Title", true)
	itemNameLabel = popupFrame:FindFirstChild("ItemName", true)
	messageLabel  = popupFrame:FindFirstChild("Message", true)
	confirmButton = popupFrame:FindFirstChild("ConfirmButton", true)
	cancelButton  = popupFrame:FindFirstChild("CancelButton", true)
	exitButton    = popupFrame:FindFirstChild("ExitButton", true)

	priceDisplay = popupFrame:FindFirstChild("PriceDisplay", true)
	if priceDisplay then
		currencyIcon = priceDisplay:FindFirstChild("CurrencyIcon")
		priceText    = priceDisplay:FindFirstChild("PriceText")
	end

	root.Visible = false
end

-- Search PlayerGui for the popup (it lives in its own ScreenGui)
popup = findTaggedDescendant(playerGui, "PurchasePopup")
if popup then
	resolvePopupChildren(popup)
end

-- ---------------------------------------------------------------------------
-- Popup state
-- ---------------------------------------------------------------------------
local currentEntry = nil
local awaitingResult = false
local connections = {}

local function disconnectAll()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
end

local function showConfirmState()
	if titleLabel then titleLabel.Visible = true end
	if itemNameLabel then itemNameLabel.Visible = true end
	if priceDisplay then priceDisplay.Visible = true end
	if confirmButton then confirmButton.Visible = true end
	if cancelButton then cancelButton.Visible = true end
	if messageLabel then messageLabel.Visible = false end
	if exitButton then exitButton.Visible = false end
end

local function showNotAffordableState()
	if titleLabel then titleLabel.Visible = true end
	if itemNameLabel then itemNameLabel.Visible = true end
	if priceDisplay then priceDisplay.Visible = true end
	if confirmButton then confirmButton.Visible = true end
	if cancelButton then cancelButton.Visible = true end
	if messageLabel then messageLabel.Visible = true end
	if exitButton then exitButton.Visible = false end
end

local function showResultState(message)
	if titleLabel then titleLabel.Visible = false end
	if itemNameLabel then itemNameLabel.Visible = false end
	if priceDisplay then priceDisplay.Visible = false end
	if confirmButton then confirmButton.Visible = false end
	if cancelButton then cancelButton.Visible = false end
	if messageLabel then
		messageLabel.Text = message
		messageLabel.Visible = true
	end
	if exitButton then exitButton.Visible = true end
	awaitingResult = false
end

local function closePopup()
	if popup then popup.Visible = false end
	currentEntry = nil
	awaitingResult = false
	disconnectAll()
	-- Let HUDController's restoreCamera handle cursor/camera state
	-- by re-firing the panel logic (a panel is still open behind the popup)
end

local function openPopup(entry)
	if not popup then
		warn("[PurchasePopup] Popup not found — tag a TextButton with 'PurchasePopup' in PurchasePopupGui")
		return
	end

	disconnectAll()
	currentEntry = entry
	awaitingResult = false

	local cost, currencyType, icon = getEntryCost(entry)
	local gold = player:GetAttribute("Gold") or 0
	local canAfford = (currencyType ~= "robux") and (gold >= cost)

	if titleLabel then titleLabel.Text = getCategoryLabel(entry) end
	if itemNameLabel then itemNameLabel.Text = entry.displayName or entry.name end
	if currencyIcon then currencyIcon.Image = icon end
	if priceText then priceText.Text = formatNumber(cost) end

	if currencyType == "robux" then
		showNotAffordableState()
		if messageLabel then messageLabel.Text = "" end
		if confirmButton then confirmButton.Text = "Not Available" end
	elseif not canAfford then
		showNotAffordableState()
		if messageLabel then messageLabel.Text = "Not enough gold!" end
		if confirmButton then confirmButton.Text = "Not Enough Gold" end
	else
		showConfirmState()
		if confirmButton then confirmButton.Text = "Confirm" end
	end

	if confirmButton then
		table.insert(connections, confirmButton.Activated:Connect(function()
			if not currentEntry or awaitingResult then return end
			local c, cType = getEntryCost(currentEntry)
			if cType == "robux" then return end
			local currentGold = player:GetAttribute("Gold") or 0
			if currentGold < c then
				showNotAffordableState()
				if messageLabel then messageLabel.Text = "Not enough gold!" end
				if confirmButton then confirmButton.Text = "Not Enough Gold" end
				return
			end
			awaitingResult = true
			confirmButton.Text = "Purchasing..."
			PurchaseWeapon:FireServer(currentEntry.name)
		end))
	end

	if cancelButton then
		table.insert(connections, cancelButton.Activated:Connect(function()
			if awaitingResult then return end
			closePopup()
		end))
	end

	if exitButton then
		table.insert(connections, exitButton.Activated:Connect(function()
			closePopup()
		end))
	end

	-- Background dismiss: detect clicks outside PopupFrame via UserInputService.
	-- The popup is a Frame (not a TextButton) so we can't use Activated.
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not popup.Visible then return end
		if awaitingResult then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if popupFrame and isInsideGui(popupFrame, input.Position) then return end
		closePopup()
	end))

	-- Ensure cursor is free and visible while popup is open, even if the
	-- player scrolled into first person in Classic camera mode.
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	popup.Visible = true
end

-- ---------------------------------------------------------------------------
-- Server purchase responses
-- ---------------------------------------------------------------------------
PurchaseWeapon.OnClientEvent:Connect(function(result)
	if not popup or not popup.Visible then return end
	if result.success then
		showResultState("Purchased!")
	else
		showResultState(result.message or "Purchase failed.")
	end
end)

-- ---------------------------------------------------------------------------
-- Listen for purchase requests from other scripts
-- ---------------------------------------------------------------------------
local requestEvent = lobbyUI:FindFirstChild("RequestPurchase")
if not requestEvent then
	requestEvent = Instance.new("BindableEvent")
	requestEvent.Name = "RequestPurchase"
	requestEvent.Parent = lobbyUI
end
requestEvent.Event:Connect(function(entry)
	openPopup(entry)
end)

-- ESC closes the popup
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape and popup and popup.Visible then
		if not awaitingResult then
			closePopup()
		end
	end
end)

-- Close popup on respawn or InGame change so it doesn't get orphaned
player.CharacterAdded:Connect(function()
	if popup and popup.Visible then
		closePopup()
	end
end)

player.AttributeChanged:Connect(function(attr)
	if attr == "InGame" and popup and popup.Visible then
		closePopup()
	end
end)
