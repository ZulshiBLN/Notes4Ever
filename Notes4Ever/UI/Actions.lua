local addonName, ns = ...

local L, Model, View, Transfer, Storage = ns.L, ns.Model, ns.View, ns.Transfer, ns.Storage

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

-- The confirmation for delete and discard: two lines the caller passes.
-- A layout with no words to translate, so not an L key - locales_spec
-- wants every key to read differently in German.
local CONFIRM_LINES = "%s\n%s"

-- `data.apply` does the change, so Cancel and Escape change nothing.
StaticPopupDialogs.NOTES4EVER_DELETE = {
    text = CONFIRM_LINES,
    button1 = YES,
    button2 = NO,
    showAlert = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, data)
        data.apply()
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
    StaticPopup_Show("NOTES4EVER_DELETE", L.DELETE_CONFIRM:format(summary.title),
        L.DELETE_COUNTS:format(summary.folders, summary.pages), {
        apply = function()
            ns.Editor.Flush()
            Model.delete(tables()[row.table], row.id)
            -- If the open page went with it, this flush finds it gone and closes.
            ns.Editor.Flush()
        end,
    })
end

-- Recovery entries, on the root of their table ---------------------------

local function restore(row, entry, when)
    ns.Editor.Flush()
    -- A refusal can only come from the list changing under an open menu;
    -- the refresh shows it as it now is.
    Storage.restore(tables()[row.table], entry, L.RESTORED_TITLE:format(when), L.UNTITLED, time())
    ns.Tree.Expand(row.table, row.id)
    ns.Tree.Refresh()
end

local function confirmDiscard(row, entry, when, reason, final)
    StaticPopup_Show("NOTES4EVER_DELETE", L.DISCARD_CONFIRM:format(when, reason), final, {
        apply = function() Storage.discard(tables()[row.table], entry) end,
    })
end

-- In stored order, as the warning counts them; Restore only where the data
-- can come back, Discard for every entry.
local function addRecovery(menu, row)
    local db = tables()[row.table]
    if Storage.recoveryCount(db) == 0 then return end
    local recoveryMenu = menu:CreateButton(L.MENU_RECOVERY)
    for _, entry in ipairs(db.recovery) do
        local when, reason, final = Storage.describe(entry, L, date)
        local item = recoveryMenu:CreateButton(when .. " - " .. reason)
        if Storage.restorable(entry) then
            item:CreateButton(L.MENU_RESTORE, function() restore(row, entry, when) end)
        end
        item:CreateButton(L.MENU_DISCARD, function() confirmDiscard(row, entry, when, reason, final) end)
    end
end

-- Text typed within the save pause belongs in the export.
local function export(row)
    ns.Editor.Flush()
    local text = Transfer.export(tables()[row.table], row.id)
    if text then ns.Dialog.ShowExport(text) end
end

function Actions.ShowMenu(owner, row)
    MenuUtil.CreateContextMenu(owner, function(_, menu)
        if row.kind == "folder" then
            menu:CreateButton(L.MENU_NEW_FOLDER, function() create(row, "folder") end)
            menu:CreateButton(L.MENU_NEW_PAGE, function() create(row, "page") end)
            menu:CreateButton(L.MENU_IMPORT, function() ns.Dialog.ShowImport(row.table, row.id) end)
        end
        -- An empty root has nothing to export; parse would refuse its export.
        local exportButton = menu:CreateButton(L.MENU_EXPORT, function() export(row) end)
        if row.isRoot and not row.hasChildren then exportButton:SetEnabled(false) end
        if row.isRoot then
            addRecovery(menu, row)
            return
        end

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
