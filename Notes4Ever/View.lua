local addonName, ns = ...

-- What the window shows, worked out without WoW: API-free like the model, so
-- busted runs all of it. The frames in UI/ only draw what this returns.
local Model = ns.Model
local View = {}
ns.View = View

View.MIN_WIDTH = 400
View.MIN_HEIGHT = 300

View.DEFAULT_GEOMETRY = {
    point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 640, height = 420,
}

local POINTS = {
    CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

-- A finite number, or nil: NaN and infinities fail the comparisons below.
local function finite(value)
    if type(value) == "number" and value > -math.huge and value < math.huge then
        return value
    end
end

-- Rows of the tree --------------------------------------------------------

-- Ids are unique per table, not across them, so a row's key carries both.
local function keyOf(tableName, id)
    return tableName .. ":" .. id
end
View.key = keyOf

-- `expanded` holds what the player opened or closed, by row key. Anything
-- not in it takes the default: roots open, folders closed.
local function isExpanded(expanded, key, isRoot)
    local state = expanded[key]
    if state == nil then return isRoot end
    return state
end

-- The tree as the window shows it: both roots, account first, each followed
-- by its visible notes in stored order with their depth. A collapsed folder
-- hides its whole subtree. `labels` gives the roots' titles.
function View.rows(account, character, expanded, labels)
    local rows = {}
    local function add(tableName, node, depth, isRoot)
        local key = keyOf(tableName, node.id)
        local hasChildren = node.children ~= nil and #node.children > 0
        local open = hasChildren and isExpanded(expanded, key, isRoot)
        rows[#rows + 1] = {
            key = key, table = tableName, id = node.id, kind = node.kind,
            title = isRoot and labels[tableName] or node.title,
            depth = depth, isRoot = isRoot,
            hasChildren = hasChildren, expanded = open,
        }
        if open then
            for _, child in ipairs(node.children) do add(tableName, child, depth + 1, false) end
        end
    end
    add("account", account.root, 0, true)
    add("character", character.root, 0, true)
    return rows
end

-- Opens a closed row or closes an open one.
function View.toggle(expanded, row)
    expanded[row.key] = not isExpanded(expanded, row.key, row.isRoot)
end

-- Tree actions ------------------------------------------------------------

-- Where a node may move: every folder of both tables, roots included, in
-- tree order - except the node itself and its subtree, which Model.move
-- would refuse. A folder in the other table is never excluded, even when
-- its id matches. Nil for a root, which cannot move.
function View.moveTargets(account, character, tableName, id, labels)
    local tables = { account = account, character = character }
    local node, parent = Model.find(tables[tableName], id)
    if not node or not parent then return nil end

    local targets = {}
    local function add(name, folder, depth, isRoot)
        if name == tableName and folder == node then return end
        targets[#targets + 1] = {
            table = name, id = folder.id, depth = depth,
            title = isRoot and labels[name] or folder.title,
        }
        for _, child in ipairs(folder.children) do
            if child.kind == "folder" then add(name, child, depth + 1, false) end
        end
    end
    add("account", account.root, 0, true)
    add("character", character.root, 0, true)
    return targets
end

-- What a delete would remove, for the confirmation: the node's title and
-- how many folders and pages go, the node itself included. Nil for a root.
function View.deleteSummary(db, id)
    local node, parent = Model.find(db, id)
    if not node or not parent then return nil end
    local summary = { title = node.title, folders = 0, pages = 0 }
    local function count(n)
        if n.kind == "folder" then
            summary.folders = summary.folders + 1
            for _, child in ipairs(n.children) do count(child) end
        else
            summary.pages = summary.pages + 1
        end
    end
    count(node)
    return summary
end

-- The editor ---------------------------------------------------------------

-- What the editor shows and what it has not written yet. The frame calls
-- editorType on every keystroke and editorFlush on each trigger: a pause,
-- hiding the window, opening another page, before a tree action, logout.
function View.newEditor()
    return {}
end

-- The open page as { table = , id = }, or nil.
function View.editorPage(editor)
    return editor.page
end

-- Writes pending text to the open page. True if something was written.
-- If the page is gone - deleted while open - nothing is written and the
-- editor closes: text must never land on a page that no longer exists.
function View.editorFlush(editor, tables, now)
    local page = editor.page
    if not page then return false end
    -- Checked before anything else: a page deleted while open must close the
    -- editor even with nothing typed, or the player types into a ghost and
    -- that text is dropped at the next flush.
    if not Model.find(tables[page.table], page.id) then
        editor.page = nil
        editor.pending = nil
        return false
    end
    if editor.pending == nil then return false end
    local text = editor.pending
    editor.pending = nil
    Model.setText(tables[page.table], page.id, text, now)
    return true
end

-- Opens a page, writing the previous one's pending text first, and returns
-- the text to show - nil if there is no such page.
function View.editorOpen(editor, tables, tableName, id, now)
    View.editorFlush(editor, tables, now)
    local node = Model.find(tables[tableName], id)
    if not node or node.kind ~= "page" then
        editor.page = nil
        return nil
    end
    editor.page = { table = tableName, id = id }
    return node.text
end

function View.editorType(editor, text)
    if editor.page then editor.pending = text end
end

-- After a move: across tables every id in the moved subtree changed, and
-- `ids` maps old to new. The open page follows if it was in that subtree.
function View.editorFollow(editor, fromTable, toTable, ids)
    local page = editor.page
    if not page or not ids or page.table ~= fromTable then return end
    local newId = ids[page.id]
    if newId then editor.page = { table = toTable, id = newId } end
end

-- The stored window geometry, made safe to apply. Whatever is missing or
-- malformed takes its default - the field is a convenience and is never
-- trusted - and a size below the minimum is raised to it.
function View.geometry(ui)
    local d = View.DEFAULT_GEOMETRY
    if type(ui) ~= "table" then ui = {} end
    return {
        point         = POINTS[ui.point] and ui.point or d.point,
        relativePoint = POINTS[ui.relativePoint] and ui.relativePoint or d.relativePoint,
        x             = finite(ui.x) or d.x,
        y             = finite(ui.y) or d.y,
        width         = math.max(finite(ui.width) or d.width, View.MIN_WIDTH),
        height        = math.max(finite(ui.height) or d.height, View.MIN_HEIGHT),
    }
end
