-- Automatically wires up tagged GuiButtons to toggle panels.
-- Supported tags: ToggleShop, ToggleSettings, ToggleLoadout, ClosePanel
-- Tag buttons in Studio via the Properties panel or the Tag Editor plugin.

local CollectionService = game:GetService("CollectionService")

local lobbyUI = script:FindFirstAncestor("LobbyUI")
local toggleEvent = lobbyUI:WaitForChild("TogglePanel")

local TAGS = {
	{ tag = "ToggleShop",     panel = "shop" },
	{ tag = "ToggleSettings", panel = "settings" },
	{ tag = "ToggleLoadout",  panel = "loadout" },
	{ tag = "ClosePanel",     panel = nil },  -- fires nil → closes whatever is open
}

local function wireButton(button, panelName)
	if not button:IsA("GuiButton") then return end
	button.Activated:Connect(function()
		toggleEvent:Fire(panelName)
	end)
end

for _, entry in TAGS do
	for _, button in CollectionService:GetTagged(entry.tag) do
		wireButton(button, entry.panel)
	end
	CollectionService:GetInstanceAddedSignal(entry.tag):Connect(function(button)
		wireButton(button, entry.panel)
	end)
end
