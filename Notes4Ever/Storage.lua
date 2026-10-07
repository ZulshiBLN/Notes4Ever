local addonName, ns = ...

-- Turning what the client hands back into a usable table without ever
-- losing it. API-free like the model: time and the character's GUID come in.
--
-- The rule: what cannot be read is never overwritten. A table that is
-- malformed, or whose migration fails, is kept unchanged in the `recovery`
-- list of a fresh table, and the player is told until it is restored.
local Model = ns.Model
local Storage = {}
ns.Storage = Storage

-- Upgrades by schema version: migrations[v] turns a v table into v + 1.
-- Schema 1 is the first, so there are none yet.
Storage.migrations = {}

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

-- One message per table with recovery entries, until plan 3 can restore them.
function Storage.warnings(account, character, L)
    local messages = {}
    for _, entry in ipairs({ { account, "account", L.ROOT_ACCOUNT },
                             { character, "character", L.ROOT_CHARACTER } }) do
        local db, file, label = entry[1], entry[2], entry[3]
        if db.recovery and #db.recovery > 0 then
            messages[#messages + 1] = L.WARN_RECOVERY:format(#db.recovery, label, PATHS[file], PATHS[file])
        end
    end
    return messages
end
