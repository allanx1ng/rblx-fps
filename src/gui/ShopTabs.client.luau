-- Wires up tagged buttons inside ShopPanel to switch between sub-pages.
-- Lives at: LobbyUI > ShopTabs (LocalScript)
--
-- Supported tags (on GuiButtons):
--   ShopTabFeatured, ShopTabWeapons, ShopTabItems, ShopTabBuffs
--
-- Supported tags (on Frames inside ShopItems):
--   ShopPageFeatured, ShopPageWeapons, ShopPageItems, ShopPageBuffs

local CollectionService = game:GetService("CollectionService")

local lobbyUI = script:FindFirstAncestor("LobbyUI")
local main = lobbyUI:WaitForChild("Main")
local shopPanel = main:WaitForChild("ShopPanel")

local TABS = {
	{ button = "ShopTabFeatured", page = "ShopPageFeatured" },
	{ button = "ShopTabWeapons",  page = "ShopPageWeapons" },
	{ button = "ShopTabItems",    page = "ShopPageItems" },
	{ button = "ShopTabBuffs",    page = "ShopPageBuffs" },
}

local function findAllTaggedDescendants(tag)
	local results = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(shopPanel) then
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

-- Force ALL pages hidden on startup
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

-- Wire buttons
local wiredButtons = {}

local function wireButton(button, pageTag)
	if not button:IsA("GuiButton") then return end
	if wiredButtons[button] then return end
	wiredButtons[button] = true

	button.Activated:Connect(function()
		showPage(pageTag)
	end)
end

for _, tab in TABS do
	for _, button in findAllTaggedDescendants(tab.button) do
		wireButton(button, tab.page)
	end

	CollectionService:GetInstanceAddedSignal(tab.button):Connect(function(button)
		if button:IsDescendantOf(shopPanel) then
			wireButton(button, tab.page)
		end
	end)

	CollectionService:GetInstanceAddedSignal(tab.page):Connect(function(page)
		if page:IsDescendantOf(shopPanel) then
			pages[tab.page] = page
			page.Visible = false
		end
	end)
end

-- Default to featured
showPage("ShopPageFeatured")

-- Reset to featured when shop is closed
shopPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not shopPanel.Visible then
		showPage("ShopPageFeatured")
	end
end)
