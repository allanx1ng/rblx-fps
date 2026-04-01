-- Automatically wires up any GuiButton tagged "ToggleShop" to toggle the shop panel.
-- Also supports "ToggleSettings" and "ToggleLoadout" tags.
-- Tag buttons in Studio via the Properties panel or the Tag Editor plugin.

local CollectionService = game:GetService("CollectionService")

local lobbyUI = script:FindFirstAncestor("LobbyUI")
local toggleEvent = lobbyUI:WaitForChild("TogglePanel")

local TAG_TO_PANEL = {
	ToggleShop     = "shop",
	ToggleSettings = "settings",
	ToggleLoadout  = "loadout",
}

local function wireButton(button, panelName)
	if not button:IsA("GuiButton") then return end
	button.Activated:Connect(function()
		toggleEvent:Fire(panelName)
	end)
end

for tag, panelName in TAG_TO_PANEL do
	for _, button in CollectionService:GetTagged(tag) do
		wireButton(button, panelName)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(button)
		wireButton(button, panelName)
	end)
end
