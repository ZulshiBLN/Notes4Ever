local addonName, ns = ...

-- Turning what the client hands back into a usable table without ever
-- losing it. API-free like the model: time and the character's GUID come in.
--
-- The rule: what cannot be read is never overwritten. A table that is
-- malformed, or whose migration fails, is kept unchanged in the `recovery`
-- list of a fresh table, and the player is told until it is restored.
local Model, Transfer = ns.Model, ns.Transfer
local Storage = {}
ns.Storage = Storage

-- Upgrades by schema version: migrations[v] turns a v table into v + 1.
Storage.migrations = {
    -- Schema 2 may carry `ui`, the window geometry. It is optional and read
    -- with defaults, so a schema 1 table needs no change, only the new number.
    [1] = function() end,
}

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = deepCopy(v) end
    return copy
end

local function fail(reason) error(reason, 0) end

local function validateNode(node, seen)
    if type(node) ~= "table" then fail("node_not_a_table") end
    if type(node.id) ~= "number" then fail("bad_id") end
    if seen[node.id] then fail("duplicate_id") end
    seen[node.id] = true
    if not Model.KINDS[node.kind] then fail("unknown_kind") end
    if node.kind == "folder" then
        if type(node.children) ~= "table" then fail("folder_without_children") end
        for _, child in ipairs(node.children) do validateNode(child, seen) end
    elseif type(node.text) ~= "string" then
        fail("page_without_text")
    end
end

-- Validation and migration both work on `db`, a copy; the original is only
-- ever read.
local function upgrade(db, target, migrations)
    if type(db.schemaVersion) ~= "number" then fail("missing_schema") end
    if db.schemaVersion > target then fail("newer_schema") end
    while db.schemaVersion < target do
        local migrate = migrations[db.schemaVersion]
        if not migrate then fail("no_migration_from_" .. db.schemaVersion) end
        migrate(db)
        db.schemaVersion = db.schemaVersion + 1
    end

    if type(db.root) ~= "table" then fail("root_not_a_table") end
    if db.root.kind ~= "folder" then fail("root_not_a_folder") end
    local seen = {}
    validateNode(db.root, seen)

    -- A counter at or below an id in use would hand that id out again.
    local largest = 0
    for id in pairs(seen) do if id > largest then largest = id end end
    if type(db.nextId) ~= "number" or db.nextId <= largest then
        db.nextId = largest + 1
    end
end

-- Earlier recovery entries travel with the table, whatever else happens.
local function carriedRecovery(saved, now)
    if type(saved) ~= "table" or saved.recovery == nil then return {} end
    if type(saved.recovery) == "table" then return deepCopy(saved.recovery) end
    return { { reason = "recovery_not_a_list", at = now, data = saved.recovery } }
end

-- Returns the table to use. `options` lets tests supply a schema version
-- and migrations; the addon uses the defaults.
function Storage.load(saved, now, options)
    options = options or {}
    local target = options.schemaVersion or Model.SCHEMA_VERSION
    local migrations = options.migrations or Storage.migrations

    if saved == nil then
        local db = Model.newTable(now)
        db.loads = 1
        return db
    end

    local recovery = carriedRecovery(saved, now)
    local input = deepCopy(saved)
    if type(input) == "table" then input.recovery = nil end

    local db = deepCopy(input)
    local ok, reason = pcall(function()
        if type(db) ~= "table" then fail("not_a_table") end
        upgrade(db, target, migrations)
    end)

    if ok then
        db.loads = (tonumber(db.loads) or 0) + 1
        if #recovery > 0 then db.recovery = recovery end
        return db
    end

    local fresh = Model.newTable(now)
    fresh.loads = 1
    recovery[#recovery + 1] = { reason = reason, at = now, data = input }
    fresh.recovery = recovery
    return fresh
end

-- Nodes below the root.
function Storage.count(db)
    local function walk(node)
        local n = 1
        for _, child in ipairs(node.children or {}) do n = n + walk(child) end
        return n
    end
    return walk(db.root) - 1
end

local function recordLost(db, file, expected, now)
    db.recovery = db.recovery or {}
    db.recovery[#db.recovery + 1] = { reason = "lost", file = file, expected = expected, at = now }
end

-- At login: each table checks what the other said about it last time, then
-- records what it sees now. A table that arrived nil although its partner
-- counted notes in it was lost. `guid` is nil when it may not be used.
function Storage.reconcile(account, character, guid, now, arrived)
    arrived = arrived or {}

    local counted = guid and account.characters and account.characters[guid] or 0
    if arrived.characterArrivedNil and counted > 0 then
        recordLost(character, "character", counted, now)
    end
    if arrived.accountArrivedNil and (character.accountCount or 0) > 0 then
        recordLost(account, "account", character.accountCount, now)
    end

    if guid then
        account.characters = account.characters or {}
        account.characters[guid] = Storage.count(character)
    end
    character.accountCount = Storage.count(account)
end

local PATHS = {
    account   = [[WTF\Account\<account>\SavedVariables\Notes4Ever.lua]],
    character = [[WTF\Account\<account>\<realm>\<character>\SavedVariables\Notes4Ever.lua]],
}

-- The recovery list is carried over as stored and may have holes. The
-- warning, the root menu and /n4e status all count what ipairs reaches, so
-- none of them names an entry the menu cannot show.
function Storage.recoveryCount(db)
    local count = 0
    if type(db.recovery) == "table" then
        for _ in ipairs(db.recovery) do count = count + 1 end
    end
    return count
end

-- One message per table with recovery entries, saying to copy the files and
-- where to restore or discard them.
function Storage.warnings(account, character, L)
    local messages = {}
    for _, entry in ipairs({ { account, "account", L.ROOT_ACCOUNT },
                             { character, "character", L.ROOT_CHARACTER } }) do
        local db, file, label = entry[1], entry[2], entry[3]
        local count = Storage.recoveryCount(db)
        if count > 0 then
            -- format cannot reuse an argument, so the label goes in twice.
            messages[#messages + 1] = L.WARN_RECOVERY:format(count, label, PATHS[file], PATHS[file], label)
        end
    end
    return messages
end

-- Restoring ---------------------------------------------------------------
--
-- A recovery entry's `data` is the unreadable table as it was. Salvage
-- reads what it still can; the rest goes, a malformed node with its
-- subtree. What comes back has Transfer.parse's shape, so restore inserts
-- it the way an import does.

local function salvageNode(node, untitled)
    if type(node) ~= "table" then return nil end
    local title = node.title
    if type(title) ~= "string" or not title:find("%S") then title = untitled end
    local plain = { kind = node.kind, title = title }
    if node.kind == "folder" and type(node.children) == "table" then
        plain.children = {}
        for _, child in ipairs(node.children) do
            plain.children[#plain.children + 1] = salvageNode(child, untitled)
        end
    elseif node.kind == "page" and type(node.text) == "string" then
        plain.text = node.text
    else
        return nil
    end
    return plain
end

-- The readable notes below `data`'s root, or an empty list. The root's own
-- kind is not checked: its children are what the player wrote.
function Storage.salvage(data, untitled)
    local nodes = {}
    if type(data) ~= "table" or type(data.root) ~= "table" or type(data.root.children) ~= "table" then
        return nodes
    end
    for _, child in ipairs(data.root.children) do
        nodes[#nodes + 1] = salvageNode(child, untitled)
    end
    return nodes
end

-- Decided by the data, not the reason: going back to an older build files
-- the current schema's data as newer_schema, and that must come back.
-- Data above the current schema waits for an update that reads it in full.
function Storage.restorable(entry)
    if type(entry) ~= "table" or type(entry.data) ~= "table" then return false end
    local version = entry.data.schemaVersion
    if type(version) == "number" and version > Model.SCHEMA_VERSION then return false end
    -- Emptiness does not depend on the placeholder title.
    return #Storage.salvage(entry.data, "") > 0
end

-- By identity, not position: a restore while a discard waits for its
-- confirmation shifts the list.
local function indexOf(db, entry)
    if type(db.recovery) ~= "table" then return nil end
    for i, candidate in ipairs(db.recovery) do
        if candidate == entry then return i end
    end
end

local function remove(db, index)
    table.remove(db.recovery, index)
    if #db.recovery == 0 then db.recovery = nil end
end

-- Puts an entry's readable notes into a new folder `title` in the root and
-- removes the entry. Nil and a reason, changing nothing, if the entry is
-- gone or cannot be restored.
function Storage.restore(db, entry, title, untitled, now)
    local index = indexOf(db, entry)
    if not index then return nil, "gone" end
    if not Storage.restorable(entry) then return nil, "not_restorable" end
    local folder, err = Model.create(db, db.root.id, "folder", title, now)
    if not folder then return nil, err end
    Transfer.insert(db, folder.id, Storage.salvage(entry.data, untitled), now)
    remove(db, index)
    return folder
end

-- Removes an entry for good. Nil and "gone" if it is no longer there.
function Storage.discard(db, entry)
    local index = indexOf(db, entry)
    if not index then return nil, "gone" end
    remove(db, index)
    return true
end

local function dateLabel(at, L, formatDate)
    if not Model.finite(at) then return L.DATE_UNKNOWN end
    -- WoW's date() is passed in; an out-of-range time can make it fail.
    local ok, text = pcall(formatDate, "%Y-%m-%d %H:%M", at)
    if ok and type(text) == "string" then return text end
    return L.DATE_UNKNOWN
end

-- The entry's date and reason as the menu shows them, and the final line of
-- Discard's confirmation. An entry that is not a table is never read.
function Storage.describe(entry, L, formatDate)
    if type(entry) ~= "table" then
        return L.DATE_UNKNOWN, L.REASON_UNREADABLE, L.DISCARD_FINAL
    end
    if entry.reason == "lost" then
        return dateLabel(entry.at, L, formatDate), L.REASON_LOST, L.DISCARD_LOST_FINAL
    end
    local reason = entry.reason == "newer_schema" and L.REASON_NEWER or L.REASON_UNREADABLE
    return dateLabel(entry.at, L, formatDate), reason, L.DISCARD_FINAL
end
