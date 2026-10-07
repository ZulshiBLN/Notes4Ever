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

-- Every action writes the editor's pending text first: a move across
-- tables changes ids, and a delete would otherwise take typed text along.
-- The name popup serves rename and create; `data.apply` does the change,
-- so Cancel and Escape change nothing - a new node exists only once named.
local function applyName(popup, data)
    ns.Editor.Flush()
    data.apply(editBoxOf(popup):GetText())
    ns.Tree.Refresh()
end

-- Text from L; the buttons use the game's own localised words.
StaticPopupDialogs.NOTES4EVER_NAME = {
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
    OnAccept = applyName,
    EditBoxOnEnterPressed = function(edit, data)
        local popup = edit:GetParent()
        applyName(popup, data)
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
        ns.Editor.Flush()
        Model.delete(tables()[data.table], data.id)
        -- If the open page went with it, this flush finds it gone and closes.
        ns.Editor.Flush()
        ns.Tree.Refresh()
    end,
}

local function askRename(row)
    StaticPopup_Show("NOTES4EVER_NAME", nil, nil, {
        title = row.title,
        apply = function(text)
            Model.rename(tables()[row.table], row.id, text, time())
        end,
    })
end

-- A new folder or page is named first and created on Accept, in the clicked
-- folder, which opens. A blank name creates nothing - Model refuses it.
local function create(row, kind)
    StaticPopup_Show("NOTES4EVER_NAME", nil, nil, {
        title = kind == "folder" and L.NEW_FOLDER_TITLE or L.NEW_PAGE_TITLE,
        apply = function(text)
            if Model.create(tables()[row.table], row.id, kind, text, time()) then
                ns.Tree.Expand(row.table, row.id)
            end
        end,
    })
end

local function move(row, target)
    ns.Editor.Flush()
    local db = tables()
    local selected = ns.Tree.Selected()
    local moved, ids = Model.move(db[row.table], row.id, db[target.table], target.id, time())
    if not moved then return end
    -- Across tables every id in the moved subtree changed. The selection and
    -- the editor follow a page that moved - itself or inside a folder.
    if ids and selected and selected.table == row.table and ids[selected.id] then
        ns.Tree.Select(target.table, ids[selected.id])
    end
    ns.Editor.Follow(row.table, target.table, ids)
    ns.Tree.Expand(target.table, target.id)
    ns.Tree.Refresh()
end

local function confirmDelete(row)
    ns.Editor.Flush()
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

        menu:CreateButton(L.MENU_RENAME, function() askRename(row) end)
        local moveMenu = menu:CreateButton(L.MENU_MOVE)
        local targets = View.moveTargets(Notes4EverDB, Notes4EverCharDB, row.table, row.id, labels())
        for _, target in ipairs(targets or {}) do
            local indent = string.rep("   ", target.depth)
            moveMenu:CreateButton(indent .. target.title, function() move(row, target) end)
        end
        menu:CreateButton(L.MENU_DELETE, function() confirmDelete(row) end)
    end)
end
