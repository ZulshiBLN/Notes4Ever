local addonName, ns = ...

local L, Model, View = ns.L, ns.Model, ns.View

-- The tree's right-click menu and the two dialogs behind it: new folder or
-- page, rename, move, delete. What is allowed - move targets, what a delete
-- removes - comes from View; the changes themselves from Model.
local Actions = {}
ns.Actions = Actions

local function tables()
    return { account = Notes4EverDB, character = Notes4EverCharDB }
end

local function labels()
    return { account = L.ROOT_ACCOUNT, character = L.ROOT_CHARACTER }
end

-- The popup's edit box moved between client versions: a method on newer
-- clients, a field on older ones.
local function editBoxOf(popup)
    if popup.GetEditBox then return popup:GetEditBox() end
    return popup.editBox or popup.EditBox
end

local function rename(popup, data)
    Model.rename(tables()[data.table], data.id, editBoxOf(popup):GetText(), time())
    ns.Tree.Refresh()
end

-- Text from L; the buttons use the game's own localised words.
StaticPopupDialogs.NOTES4EVER_RENAME = {
    text = L.RENAME_PROMPT,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 200,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(popup, data)
        local edit = editBoxOf(popup)
        edit:SetText(data.title)
        edit:HighlightText()
        edit:SetFocus()
    end,
    OnAccept = rename,
    EditBoxOnEnterPressed = function(edit, data)
        local popup = edit:GetParent()
        rename(popup, data)
        popup:Hide()
    end,
    EditBoxOnEscapePressed = function(edit)
        edit:GetParent():Hide()
    end,
}

StaticPopupDialogs.NOTES4EVER_DELETE = {
    text = L.DELETE_CONFIRM,
    button1 = YES,
    button2 = NO,
    showAlert = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, data)
        Model.delete(tables()[data.table], data.id)
        ns.Tree.Refresh()
    end,
}

local function askRename(tableName, node)
    StaticPopup_Show("NOTES4EVER_RENAME", nil, nil,
        { table = tableName, id = node.id, title = node.title })
end

-- A new folder or page goes into the clicked folder, which opens, and is
-- named at once.
local function create(row, kind)
    local title = kind == "folder" and L.NEW_FOLDER_TITLE or L.NEW_PAGE_TITLE
    local node = Model.create(tables()[row.table], row.id, kind, title, time())
    if not node then return end
    ns.Tree.Expand(row.table, row.id)
    ns.Tree.Refresh()
    askRename(row.table, node)
end

local function move(row, target)
    local db = tables()
    local wasSelected = ns.Tree.Selected()
    local moved = Model.move(db[row.table], row.id, db[target.table], target.id, time())
    if not moved then return end
    -- A move across tables gives the page new ids; the selection follows it.
    if wasSelected and wasSelected.table == row.table and wasSelected.id == row.id then
        ns.Tree.Select(target.table, moved.id)
    end
    ns.Tree.Expand(target.table, target.id)
    ns.Tree.Refresh()
end

local function confirmDelete(row)
    local summary = View.deleteSummary(tables()[row.table], row.id)
    if not summary then return end
    StaticPopup_Show("NOTES4EVER_DELETE", summary.title,
        L.DELETE_COUNTS:format(summary.folders, summary.pages),
        { table = row.table, id = row.id })
end

function Actions.ShowMenu(owner, row)
    MenuUtil.CreateContextMenu(owner, function(_, menu)
        if row.kind == "folder" then
            menu:CreateButton(L.MENU_NEW_FOLDER, function() create(row, "folder") end)
            menu:CreateButton(L.MENU_NEW_PAGE, function() create(row, "page") end)
        end
        if row.isRoot then return end

        menu:CreateButton(L.MENU_RENAME, function()
            askRename(row.table, { id = row.id, title = row.title })
        end)
        local moveMenu = menu:CreateButton(L.MENU_MOVE)
        local targets = View.moveTargets(Notes4EverDB, Notes4EverCharDB, row.table, row.id, labels())
        for _, target in ipairs(targets or {}) do
            local indent = string.rep("   ", target.depth)
            moveMenu:CreateButton(indent .. target.title, function() move(row, target) end)
        end
        menu:CreateButton(L.MENU_DELETE, function() confirmDelete(row) end)
    end)
end
