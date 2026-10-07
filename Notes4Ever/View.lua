local addonName, ns = ...

-- What the window shows, worked out without WoW: API-free like the model, so
-- busted runs all of it. The frames in UI/ only draw what this returns.
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
