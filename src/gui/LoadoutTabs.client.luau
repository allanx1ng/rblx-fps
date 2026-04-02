-- Wires up tagged buttons inside LoadoutPanel to switch between sub-pages.
-- Lives at: LobbyUI > LoadoutTabs (LocalScript)
--
-- Supported tags (on GuiButtons):
--   LoadoutTabOverview, LoadoutTabPrimary, LoadoutTabSecondary,
--   LoadoutTabMelee, LoadoutTabItems, LoadoutTabPassives
--
-- Supported tags (on Frames — the pages themselves):
--   LoadoutPageOverview, LoadoutPagePrimary, LoadoutPageSecondary,
--   LoadoutPageMelee, LoadoutPageItems, LoadoutPagePassives
--
-- Back buttons inside sub-pages should be tagged "LoadoutTabOverview".

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

local PAGE_TAGS = {}
for _, tab in TABS do
	PAGE_TAGS[tab.page] = true
end

local function findAllTaggedDescendants(tag)
	local results = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(loadoutPanel) then
			table.insert(results, instance)
		end
	end
	return results
end

-- Resolve all pages
local pages = {}
for _, tab in TABS do
	local found = findAllTaggedDescendants(tab.page)
	if #found > 0 then
		pages[tab.page] = found[1]
	end
end

-- Force ALL pages hidden immediately on startup
for _, tab in TABS do
	local page = pages[tab.page]
	if page then
		page.Visible = false
	end
end

local function showPage(pageTag)
	for _, tab in TABS do
		local page = pages[tab.page]
		if page then
			page.Visible = (tab.page == pageTag)
		end
	end
end

-- Wire a button to show its target page
local wiredButtons = {}

local function wireButton(button, pageTag)
	if not button:IsA("GuiButton") then return end
	if wiredButtons[button] then return end
	wiredButtons[button] = true

	button.Activated:Connect(function()
		showPage(pageTag)
	end)
end

-- Wire ALL matching buttons (not just the first) — handles multiple back buttons
for _, tab in TABS do
	for _, button in findAllTaggedDescendants(tab.button) do
		wireButton(button, tab.page)
	end

	CollectionService:GetInstanceAddedSignal(tab.button):Connect(function(button)
		if button:IsDescendantOf(loadoutPanel) then
			wireButton(button, tab.page)
		end
	end)

	CollectionService:GetInstanceAddedSignal(tab.page):Connect(function(page)
		if page:IsDescendantOf(loadoutPanel) then
			pages[tab.page] = page
			page.Visible = false
		end
	end)
end

-- Now show overview as the default
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
