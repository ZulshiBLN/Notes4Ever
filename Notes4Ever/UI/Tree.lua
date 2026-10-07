local addonName, ns = ...

local L, Model, View, Skin = ns.L, ns.Model, ns.View, ns.Skin

-- The tree on the window's left: a scroll list of the rows View.rows works
-- out. Which rows exist, their depth and what is open is decided there; this
-- file only lays the rows out and turns clicks into View calls. A right
-- click opens the actions menu (UI/Actions.lua).
local Tree = {}
ns.Tree = Tree

local ROW_HEIGHT = 20
local INDENT = 14
local EXPANDER_SIZE = 14

-- What the player has opened or closed, and the selected page as
-- { table = , id = }. Per session: the tree opens with roots open and
-- folders closed.
local expanded = {}
local selected

local scrollBox

local function tables()
    return { account = Notes4EverDB, character = Notes4EverCharDB }
end

local function currentRows()
    return View.rows(Notes4EverDB, Notes4EverCharDB, expanded,
        { account = L.ROOT_ACCOUNT, character = L.ROOT_CHARACTER })
end

function Tree.Refresh()
    -- A selected page that a delete removed is no longer selected.
    if selected and not Model.find(tables()[selected.table], selected.id) then
        selected = nil
    end
    if not scrollBox then return end
    scrollBox:SetDataProvider(CreateDataProvider(currentRows()),
        ScrollBoxConstants.RetainScrollPosition)
end

-- The selected page as { table = , id = }, or nil.
function Tree.Selected()
    return selected
end

function Tree.Select(tableName, id)
    selected = { table = tableName, id = id }
end

-- Opens a folder, so a note just created or moved into it is visible.
function Tree.Expand(tableName, id)
    expanded[View.key(tableName, id)] = true
end

local function isSelected(row)
    return selected ~= nil and row.table == selected.table and row.id == selected.id
end

local function onClick(button, mouseButton)
    local row = button.row
    if mouseButton == "RightButton" then
        ns.Actions.ShowMenu(button, row)
        return
    end
    if row.hasChildren then View.toggle(expanded, row) end
    if row.kind == "page" then Tree.Select(row.table, row.id) end
    Tree.Refresh()
end

-- Row frames are recycled by the scroll box; the parts are made once.
local function initRow(button, row)
    button.row = row
    if not button.label then
        button.expander = button:CreateTexture(nil, "ARTWORK")
        button.expander:SetSize(EXPANDER_SIZE, EXPANDER_SIZE)
        button.selection = button:CreateTexture(nil, "BACKGROUND")
        button.selection:SetAllPoints()
        button.label = button:CreateFontString(nil, "OVERLAY")
        button.label:SetJustifyH("LEFT")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", onClick)
    end

    local left = 2 + row.depth * INDENT
    button.expander:ClearAllPoints()
    button.expander:SetPoint("LEFT", left, 0)
    button.expander:SetShown(row.hasChildren)
    button.selection:SetShown(isSelected(row))
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", left + EXPANDER_SIZE + 4, 0)
    button.label:SetPoint("RIGHT", -4, 0)

    -- The skin sets the font, so it comes before the text.
    Skin:Apply("treeRow", button, row)
    button.label:SetText(row.title)
end

function Tree.Create(parent)
    scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    scrollBox:SetPoint("TOPLEFT", 4, -4)
    scrollBox:SetPoint("BOTTOMLEFT", 4, 4)
    scrollBox:SetWidth(220)
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    Tree.Refresh()
end
