local addonName, ns = ...

-- The notes tree. API-free: no WoW function is called here, so every
-- operation runs under busted exactly as in the client. Time is passed in.
--
-- A table (account or character) holds one root folder and its own id
-- counter. Ids are unique within a table, not across tables; a node moved to
-- the other table gets new ids from that table's counter.
--
-- Operations return a result, or nil and a reason, and change nothing when
-- they refuse.
local Model = {}
ns.Model = Model

Model.SCHEMA_VERSION = 2

local KINDS = { folder = true, page = true }
Model.KINDS = KINDS

local function newId(db)
    local id = db.nextId
    db.nextId = id + 1
    return id
end

function Model.newTable(now)
    local db = { schemaVersion = Model.SCHEMA_VERSION, nextId = 1 }
    db.root = { id = newId(db), kind = "folder", title = "", children = {},
                created = now, modified = now }
    return db
end

-- Depth-first search; returns the node and its parent folder.
function Model.find(db, id)
    local function search(node, parent)
        if node.id == id then return node, parent end
        for _, child in ipairs(node.children or {}) do
            local found, foundParent = search(child, node)
            if found then return found, foundParent end
        end
    end
    return search(db.root, nil)
end

local function folderIn(db, id)
    local folder = Model.find(db, id)
    if not folder then return nil, "not_found" end
    if folder.kind ~= "folder" then return nil, "not_a_folder" end
    return folder
end

function Model.create(db, parentId, kind, title, now)
    if not KINDS[kind] then return nil, "bad_kind" end
    if type(title) ~= "string" or not title:find("%S") then return nil, "empty_title" end
    local parent, err = folderIn(db, parentId)
    if not parent then return nil, err end

    local node = { id = newId(db), kind = kind, title = title,
                   created = now, modified = now }
    if kind == "folder" then node.children = {} else node.text = "" end
    parent.children[#parent.children + 1] = node
    return node
end

-- A blank title is refused: a row with no text cannot be found or clicked.
function Model.rename(db, id, title, now)
    local node = Model.find(db, id)
    if not node then return nil, "not_found" end
    if type(title) ~= "string" or not title:find("%S") then return nil, "empty_title" end
    node.title = title
    node.modified = now
    return true
end

function Model.setText(db, id, text, now)
    local node = Model.find(db, id)
    if not node then return nil, "not_found" end
    if node.kind ~= "page" then return nil, "not_a_page" end
    node.text = text
    node.modified = now
    return true
end

local function detach(parent, node)
    for i, child in ipairs(parent.children) do
        if child == node then
            table.remove(parent.children, i)
            return
        end
    end
end

local function contains(node, candidate)
    if node == candidate then return true end
    for _, child in ipairs(node.children or {}) do
        if contains(child, candidate) then return true end
    end
    return false
end

local function countNodes(node)
    local count = 1
    for _, child in ipairs(node.children or {}) do count = count + countNodes(child) end
    return count
end

-- A copy of the subtree for another table: every id drawn fresh from that
-- table's counter, everything else kept. `ids` records each old id's new one.
local function copyInto(db, node, ids)
    local copy = {}
    for k, v in pairs(node) do
        if k ~= "children" then copy[k] = v end
    end
    copy.id = newId(db)
    ids[node.id] = copy.id
    if node.children then
        copy.children = {}
        for i, child in ipairs(node.children) do copy.children[i] = copyInto(db, child, ids) end
    end
    return copy
end

-- Moves a node, with its subtree, under a folder in the same or the other
-- table, and returns the node now in place: the same node within a table,
-- its copy with fresh ids across tables - then also a map from each old id
-- in the subtree to its new one. The node is inserted at the target before
-- it is removed from the source, so a refusal at the target leaves the
-- source as it was.
function Model.move(fromDb, id, toDb, toParentId, now)
    local node, parent = Model.find(fromDb, id)
    if not node then return nil, "not_found" end
    if not parent then return nil, "is_root" end

    local target, err = folderIn(toDb, toParentId)
    if not target then return nil, err end

    local moved, ids
    if fromDb == toDb then
        if contains(node, target) then return nil, "into_own_subtree" end
        moved = node
    else
        ids = {}
        moved = copyInto(toDb, node, ids)
    end
    moved.modified = now

    target.children[#target.children + 1] = moved
    -- Within one folder the node now sits twice; detach drops the first,
    -- which leaves it moved to the end.
    detach(parent, node)
    return moved, ids
end

-- Removes a node and its subtree; returns how many nodes went.
function Model.delete(db, id)
    local node, parent = Model.find(db, id)
    if not node then return nil, "not_found" end
    if not parent then return nil, "is_root" end
    local count = countNodes(node)
    detach(parent, node)
    return count
end
