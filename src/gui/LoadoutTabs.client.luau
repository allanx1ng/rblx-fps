-- Wires up tagged buttons inside LoadoutPanel to switch between sub-pages.
-- Lives at: LobbyUI > Main > LoadoutPanel > LoadoutTabs
--
-- Supported tags (on GuiButtons):
--   LoadoutTabOverview, LoadoutTabPrimary, LoadoutTabSecondary,
--   LoadoutTabMelee, LoadoutTabItems, LoadoutTabPassives
--
-- Supported tags (on Frames — the pages themselves):
--   LoadoutPageOverview, LoadoutPagePrimary, LoadoutPageSecondary,
--   LoadoutPageMelee, LoadoutPageItems, LoadoutPagePassives

local CollectionService = game:GetService("CollectionService")

local lobbyUI = script:FindFirstAncestor("LobbyUI")
local main = lobbyUI:WaitForChild("Main")
local loadoutPanel = main:WaitForChild("LoadoutPanel")

local TABS = {
	{ button = "LoadoutTabOverview",   page = "LoadoutPageOverview" },
	{ button = "LoadoutTabPrimary",    page = "LoadoutPagePrimary" },
	{ button = "LoadoutTabSecondary",  page = "LoadoutPageSecondary" },
	{ button = "LoadoutTabMelee",      page = "LoadoutPageMelee" },
	{ button = "LoadoutTabItems",      page = "LoadoutPageItems" },
	{ button = "LoadoutTabPassives",   page = "LoadoutPagePassives" },
}

local function findTaggedDescendant(tag)
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(loadoutPanel) then
			return instance
		end
	end
	return nil
end

-- Resolve all pages and buttons
local pages = {}
local buttons = {}
for _, tab in TABS do
	pages[tab.page] = findTaggedDescendant(tab.page)
	buttons[tab.button] = findTaggedDescendant(tab.button)
end

local function showPage(pageTag)
	for _, tab in TABS do
		local page = pages[tab.page]
		if page then
			page.Visible = (tab.page == pageTag)
		end
	end
end

-- Wire up buttons
for _, tab in TABS do
	local button = buttons[tab.button]
	if button and button:IsA("GuiButton") then
		button.Activated:Connect(function()
			showPage(tab.page)
		end)
	end
end

-- Also wire buttons added later
for _, tab in TABS do
	CollectionService:GetInstanceAddedSignal(tab.button):Connect(function(button)
		if button:IsA("GuiButton") and button:IsDescendantOf(loadoutPanel) then
			buttons[tab.button] = button
			button.Activated:Connect(function()
				showPage(tab.page)
			end)
		end
	end)

	CollectionService:GetInstanceAddedSignal(tab.page):Connect(function(page)
		if page:IsDescendantOf(loadoutPanel) then
			pages[tab.page] = page
		end
	end)
end

-- Default to overview on load
showPage("LoadoutPageOverview")

-- Reset to overview whenever the loadout panel is closed or another panel is opened
lobbyUI.AttributeChanged:Connect(function(attr)
	if attr == "PanelOpen" and not lobbyUI:GetAttribute("PanelOpen") then
		showPage("LoadoutPageOverview")
	end
end)

loadoutPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not loadoutPanel.Visible then
		showPage("LoadoutPageOverview")
	end
end)
