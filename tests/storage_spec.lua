-- Loading, validation, migration, recovery and the loss warnings - the part
-- of the addon whose job is that notes are never lost silently. Storage.lua
-- is API-free like the model; time and the character's GUID come in.

local addon = require("addon")

local NOW = 2000
local GUID = "Player-1234-0ABCDEF0"

-- In the TOC's order: Storage calls Transfer, Transfer calls Model.
local function loadAddon()
    local ns = {}
    addon.load("Notes4Ever/Locales/enUS.lua", ns)
    addon.load("Notes4Ever/Model.lua", ns)
    addon.load("Notes4Ever/Transfer.lua", ns)
    addon.load("Notes4Ever/Storage.lua", ns)
    return ns
end

-- Ways a saved table can be malformed, each applied to savedTable()'s
-- root -> folder "Dungeons" -> page "Deadmines". Shared by the load tests,
-- which keep each in recovery, and the salvage tests, which read it back.
local MALFORMED = {
    ["root not a table"]        = function(t) t.root = "x" end,
    ["unknown kind"]            = function(t) t.root.children[1].kind = "picture" end,
    ["folder without children"] = function(t) t.root.children[1].children = nil end,
    ["page without text"]       = function(t) t.root.children[1].children[1].text = 42 end,
    ["duplicate id"]            = function(t) t.root.children[1].children[1].id = t.root.children[1].id end,
    ["newer schemaVersion"]     = function(t) t.schemaVersion = 99 end,
    ["missing schemaVersion"]   = function(t) t.schemaVersion = nil end,
    ["root of the wrong kind"]  = function(t) t.root.kind = "page" end,
}

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepCopy(v) end
    return out
end

local function without(t, key)
    local copy = deepCopy(t)
    copy[key] = nil
    return copy
end

describe("Storage", function()
    local ns, Model, Storage

    before_each(function()
        ns = loadAddon()
        Model, Storage = ns.Model, ns.Storage
    end)

    -- A saved table as the client would hand it back: a few notes, saved once.
    local function savedTable()
        local db = Storage.load(nil, NOW)
        local folder = Model.create(db, db.root.id, "folder", "Dungeons", NOW)
        local page = Model.create(db, folder.id, "page", "Deadmines", NOW)
        Model.setText(db, page.id, "VanCleef |cffff0000 äöü", NOW)
        return db
    end

    describe("load", function()
        it("starts an absent table fresh, at the current schema, loaded once", function()
            local db = Storage.load(nil, NOW)
            assert.are.equal(Model.SCHEMA_VERSION, db.schemaVersion)
            assert.are.equal(1, db.loads)
            assert.are.equal(NOW, db.root.created)
        end)

        it("changes nothing but the load count when loading its own output again", function()
            local first = Storage.load(savedTable(), NOW + 1)
            local second = Storage.load(deepCopy(first), NOW + 2)
            assert.are.equal(first.loads + 1, second.loads)
            assert.are.same(without(first, "loads"), without(second, "loads"))
        end)

        it("does not change the table it was handed", function()
            local saved = savedTable()
            local before = deepCopy(saved)
            Storage.load(saved, NOW)
            assert.are.same(before, saved)
        end)

        it("repairs an id counter at or below the largest id", function()
            local saved = savedTable()
            saved.nextId = 1
            local db = Storage.load(saved, NOW)
            local page = Model.create(db, db.root.id, "page", "new", NOW)
            local _, parent = Model.find(db, page.id)
            assert.are.equal(db.root, parent)
            local seen = {}
            local function walk(node)
                assert.is_nil(seen[node.id], "duplicate id " .. tostring(node.id))
                seen[node.id] = true
                for _, child in ipairs(node.children or {}) do walk(child) end
            end
            walk(db.root)
        end)
    end)

    describe("migration", function()
        -- A test schema one above the real one, so these keep testing the
        -- mechanism whatever the current version is.
        local function addTags(db)
            db.tags = db.tags or {}
        end
        local function nextSchema(migrate)
            local current = Model.SCHEMA_VERSION
            return { schemaVersion = current + 1, migrations = { [current] = migrate } }
        end

        it("applies a migration once; loading its output again changes nothing", function()
            local options = nextSchema(addTags)
            local first = Storage.load(savedTable(), NOW, options)
            assert.are.equal(Model.SCHEMA_VERSION + 1, first.schemaVersion)
            assert.are.same({}, first.tags)

            local second = Storage.load(deepCopy(first), NOW, options)
            assert.are.same(without(first, "loads"), without(second, "loads"))
        end)

        -- The real migration, not a test one: schema 1 tables are what every
        -- player of 0.1.0 has on disk.
        it("brings a schema 1 table to the current schema; loading that again changes nothing", function()
            local v1 = savedTable()
            v1.schemaVersion = 1
            local first = Storage.load(deepCopy(v1), NOW)
            assert.are.equal(Model.SCHEMA_VERSION, first.schemaVersion)
            assert.are.same(v1.root, first.root)

            local second = Storage.load(deepCopy(first), NOW)
            assert.are.same(without(first, "loads"), without(second, "loads"))
        end)

        it("keeps the input unchanged in recovery when a migration raises midway", function()
            local saved = savedTable()
            local options = nextSchema(function(db)
                db.root.children = nil
                error("half done")
            end)
            local db = Storage.load(deepCopy(saved), NOW, options)
            assert.are.same({}, db.root.children)
            assert.are.equal(1, #db.recovery)
            assert.are.same(saved, db.recovery[1].data)
        end)
    end)

    describe("a malformed table", function()
        for name, breakIt in pairs(MALFORMED) do
            it("is kept deep-equal in recovery: " .. name, function()
                local saved = savedTable()
                breakIt(saved)
                local db = Storage.load(deepCopy(saved), NOW)
                assert.are.same({}, db.root.children)
                assert.are.equal(1, #db.recovery)
                assert.are.same(saved, db.recovery[1].data)
            end)
        end

        it("never replaces an earlier recovery entry, and does not nest them", function()
            local saved = savedTable()
            saved.root = "broken once"
            local once = Storage.load(saved, NOW)

            local again = deepCopy(once)
            again.root.kind = "broken twice"
            local twice = Storage.load(again, NOW + 1)

            assert.are.equal(2, #twice.recovery)
            assert.are.equal("broken once", twice.recovery[1].data.root)
            assert.are.equal("broken twice", twice.recovery[2].data.root.kind)
            assert.is_nil(twice.recovery[2].data.recovery)
        end)

        -- Window geometry is a convenience; a broken value must never hide
        -- the notes beside it. View.geometry falls back to defaults.
        it("is never caused by a malformed ui field", function()
            for _, ui in ipairs({ "garbage", 42, { width = "wide", x = {} } }) do
                local saved = savedTable()
                saved.ui = ui
                local db = Storage.load(deepCopy(saved), NOW)
                assert.is_nil(db.recovery)
                assert.are.same(saved.root, db.root)
            end
        end)

        it("keeps a table that is not a table at all", function()
            local db = Storage.load("garbage", NOW)
            assert.are.equal("garbage", db.recovery[1].data)
        end)
    end)

    describe("loss detection at login", function()
        it("records a lost character table when the account counted its notes", function()
            local account, character = savedTable(), savedTable()
            Storage.reconcile(account, character, GUID, NOW)

            local freshCharacter = Storage.load(nil, NOW)
            Storage.reconcile(account, freshCharacter, GUID, NOW, { characterArrivedNil = true })
            assert.are.equal(1, #freshCharacter.recovery)
            assert.are.equal("lost", freshCharacter.recovery[1].reason)
        end)

        it("records a lost account table when the character counted its notes", function()
            local account, character = savedTable(), savedTable()
            Storage.reconcile(account, character, GUID, NOW)

            local freshAccount = Storage.load(nil, NOW)
            Storage.reconcile(freshAccount, character, GUID, NOW, { accountArrivedNil = true })
            assert.are.equal(1, #freshAccount.recovery)
            assert.are.equal("lost", freshAccount.recovery[1].reason)
        end)

        it("treats a character the account has never counted as new", function()
            local account = savedTable()
            local newCharacter = Storage.load(nil, NOW)
            Storage.reconcile(account, newCharacter, GUID, NOW, { characterArrivedNil = true })
            assert.is_nil(newCharacter.recovery)
        end)

        -- At logout reconcile runs again with nothing arrived empty. Notes
        -- made during the session must be counted then, or losing them
        -- before the next login would go unnoticed.
        it("counts the session's new notes when called again at logout", function()
            local account, character = Storage.load(nil, NOW), Storage.load(nil, NOW)
            Storage.reconcile(account, character, GUID, NOW)
            assert.are.equal(0, account.characters[GUID])

            Model.create(character, character.root.id, "page", "written today", NOW)
            Model.create(account, account.root.id, "page", "shared", NOW)
            Storage.reconcile(account, character, GUID, NOW + 1)
            assert.are.equal(1, account.characters[GUID])
            assert.are.equal(1, character.accountCount)
            assert.is_nil(account.recovery)
            assert.is_nil(character.recovery)
        end)

        it("records nothing for a character whose GUID it may not use", function()
            local account, character = savedTable(), savedTable()
            Storage.reconcile(account, character, nil, NOW)
            assert.is_nil(account.characters)
        end)
    end)

    describe("the warning", function()
        it("names the .bak file and says to copy it before reloading", function()
            local account, character = savedTable(), savedTable()
            Storage.reconcile(account, character, GUID, NOW)
            local fresh = Storage.load(nil, NOW)
            Storage.reconcile(account, fresh, GUID, NOW, { characterArrivedNil = true })

            local messages = Storage.warnings(account, fresh, ns.L)
            assert.are.equal(1, #messages)
            assert.is_truthy(messages[1]:find("Notes4Ever.lua.bak", 1, true))
            assert.is_truthy(messages[1]:find("/reload", 1, true))
        end)

        it("says nothing when no recovery entry exists", function()
            local account, character = savedTable(), savedTable()
            assert.are.same({}, Storage.warnings(account, character, ns.L))
        end)

        it("names the root menu as where to restore", function()
            local db = Storage.load("garbage", NOW)
            local messages = Storage.warnings(db, savedTable(), ns.L)
            assert.is_truthy(messages[1]:find(ns.L.ROOT_ACCOUNT .. ".", 1, true))
            assert.is_truthy(messages[1]:find("menu", 1, true))
        end)

        it("is gone once the last entry is restored or discarded", function()
            for _, handle in ipairs({ "restore", "discard" }) do
                local saved = savedTable()
                saved.schemaVersion = nil
                local db = Storage.load(saved, NOW)
                local entry = db.recovery[1]
                if handle == "restore" then
                    assert.is_truthy(Storage.restore(db, entry, "Restored", "Untitled", NOW))
                else
                    assert.is_true(Storage.discard(db, entry))
                end
                assert.are.same({}, Storage.warnings(db, savedTable(), ns.L))
                assert.are.equal(0, Storage.recoveryCount(db))
            end
        end)

        -- A carried-over list may have holes; the warning, the menu and
        -- /n4e status count the same entries, the ones ipairs reaches.
        it("counts the entries ipairs reaches, as the menu lists them", function()
            local db = savedTable()
            db.recovery = { { reason = "lost", at = NOW }, nil, { reason = "lost", at = NOW } }
            assert.are.equal(1, Storage.recoveryCount(db))
            assert.is_truthy(Storage.warnings(db, savedTable(), ns.L)[1]:find("^Notes4Ever: 1 "))
        end)
    end)

    -- Restoring and discarding recovery entries, by plan 3's RESEARCH,
    -- Salvage per recovery entry.
    describe("recovery entries", function()
        local UNTITLED = "Untitled"
        local BOTH = { { kind = "folder", title = "Dungeons", children = {
            { kind = "page", title = "Deadmines", text = "VanCleef |cffff0000 äöü" } } } }

        -- Kinds, titles, texts and shape, without ids and timestamps.
        local function shape(node)
            local out = { kind = node.kind, title = node.title, text = node.text }
            if node.children then
                out.children = {}
                for i, child in ipairs(node.children) do out.children[i] = shape(child) end
            end
            return out
        end

        local function shapes(nodes)
            local out = {}
            for i, node in ipairs(nodes) do out[i] = shape(node) end
            return out
        end

        -- The entry a load leaves for a table broken one way.
        local function entryFor(breakIt)
            local saved = savedTable()
            breakIt(saved)
            return Storage.load(saved, NOW).recovery[1]
        end

        local function nextSchema(migrate)
            local current = Model.SCHEMA_VERSION
            return { schemaVersion = current + 1, migrations = { [current] = migrate } }
        end

        local SALVAGED = {
            ["root not a table"]        = {},
            ["unknown kind"]            = {},
            ["folder without children"] = {},
            ["page without text"]       = { { kind = "folder", title = "Dungeons", children = {} } },
            ["duplicate id"]            = BOTH,
            ["missing schemaVersion"]   = BOTH,
            ["root of the wrong kind"]  = BOTH,
        }

        for name, expected in pairs(SALVAGED) do
            it("salvages " .. name .. " as RESEARCH's table says", function()
                local entry = entryFor(MALFORMED[name])
                assert.are.same(expected, Storage.salvage(entry.data, UNTITLED))
                assert.are.equal(#expected > 0, Storage.restorable(entry))
            end)
        end

        it("salvages a table that is not a table as nothing", function()
            local entry = Storage.load("garbage", NOW).recovery[1]
            assert.are.same({}, Storage.salvage(entry.data, UNTITLED))
            assert.is_false(Storage.restorable(entry))
        end)

        it("does not restore data of a newer schema, though it reads", function()
            local entry = entryFor(MALFORMED["newer schemaVersion"])
            assert.are.same(BOTH, Storage.salvage(entry.data, UNTITLED))
            assert.is_false(Storage.restorable(entry))
        end)

        -- Going back to an older build files the current schema's data as
        -- newer_schema; plan 1b promised its restore.
        it("restores a newer_schema entry whose data is at the current schema", function()
            local older = { schemaVersion = Model.SCHEMA_VERSION - 1, migrations = {} }
            local entry = Storage.load(savedTable(), NOW, older).recovery[1]
            assert.are.equal("newer_schema", entry.reason)
            assert.are.same(BOTH, Storage.salvage(entry.data, UNTITLED))
            assert.is_true(Storage.restorable(entry))
        end)

        it("restores what a migration raising midway left", function()
            local options = nextSchema(function(db) db.root.children = nil; error("half done") end)
            local entry = Storage.load(savedTable(), NOW, options).recovery[1]
            assert.are.same(BOTH, Storage.salvage(entry.data, UNTITLED))
            assert.is_true(Storage.restorable(entry))
        end)

        it("does not restore a lost entry, which has no data", function()
            assert.is_false(Storage.restorable({ reason = "lost", file = "character", expected = 3, at = NOW }))
        end)

        it("names a title that is not a non-blank string untitled, and drops non-tables", function()
            local data = { root = { kind = "folder", children = {
                { kind = "page", title = "  ", text = "a" },
                { kind = "page", title = 7, text = "b" },
                42,
                { kind = "folder", title = "F", children = { "junk", { kind = "page", text = "c" } } },
            } } }
            assert.are.same({
                { kind = "page", title = UNTITLED, text = "a" },
                { kind = "page", title = UNTITLED, text = "b" },
                { kind = "folder", title = "F", children = { { kind = "page", title = UNTITLED, text = "c" } } },
            }, Storage.salvage(data, UNTITLED))
        end)

        it("keeps only kind, title and text or children", function()
            local data = { root = { children = { { kind = "page", title = "P", text = "t",
                id = 9, created = 1, modified = 2, junk = true } } } }
            assert.are.same({ { kind = "page", title = "P", text = "t" } }, Storage.salvage(data, UNTITLED))
        end)

        describe("restore and discard", function()
            local function twoEntries()
                local saved = savedTable()
                saved.schemaVersion = nil
                local db = Storage.load(saved, NOW)
                db.recovery[2] = { reason = "lost", file = "account", expected = 1, at = NOW }
                return db, db.recovery[1], db.recovery[2]
            end

            it("restores into a new folder in the root, with fresh ids, removing only its entry", function()
                local db, first, second = twoEntries()
                local before = #db.root.children
                local folder = assert(Storage.restore(db, first, "Restored 2026", UNTITLED, NOW + 9))
                assert.are.equal(before + 1, #db.root.children)
                assert.are.equal(folder, db.root.children[#db.root.children])
                assert.are.equal("Restored 2026", folder.title)
                assert.are.equal(NOW + 9, folder.created)
                assert.are.same(BOTH, shapes(folder.children))
                local seen = {}
                local function walk(n)
                    assert.is_nil(seen[n.id], "duplicate id " .. tostring(n.id))
                    seen[n.id] = true
                    for _, c in ipairs(n.children or {}) do walk(c) end
                end
                walk(db.root)
                assert.are.same({ second }, db.recovery)
            end)

            it("refuses an entry no longer there, and one gone is checked first", function()
                local db, first = twoEntries()
                Storage.discard(db, first)
                local ok, reason = Storage.restore(db, first, "R", UNTITLED, NOW)
                assert.is_nil(ok)
                assert.are.equal("gone", reason)
                ok, reason = Storage.discard(db, first)
                assert.is_nil(ok)
                assert.are.equal("gone", reason)
            end)

            it("refuses an unrestorable entry, which stays", function()
                local db, _, lost = twoEntries()
                local children = #db.root.children
                local ok, reason = Storage.restore(db, lost, "R", UNTITLED, NOW)
                assert.is_nil(ok)
                assert.are.equal("not_restorable", reason)
                assert.are.equal(2, #db.recovery)
                assert.are.equal(children, #db.root.children)
            end)

            it("discards only its entry, found by identity", function()
                local db, first, second = twoEntries()
                assert.is_true(Storage.discard(db, second))
                assert.are.same({ first }, db.recovery)
            end)
        end)

        describe("labels", function()
            local function formatDate(fmt, at) return fmt .. "@" .. at end
            local L

            before_each(function() L = ns.L end)

            it("dates and names an unreadable entry, with the final line for a kept copy", function()
                local date, reason, final = Storage.describe({ reason = "duplicate_id", at = 5, data = {} }, L, formatDate)
                assert.are.equal("%Y-%m-%d %H:%M@5", date)
                assert.are.equal(L.REASON_UNREADABLE, reason)
                assert.are.equal(L.DISCARD_FINAL, final)
            end)

            it("names lost and newer entries, a lost one with its own final line", function()
                local _, reason, final = Storage.describe({ reason = "lost", at = 5 }, L, formatDate)
                assert.are.equal(L.REASON_LOST, reason)
                assert.are.equal(L.DISCARD_LOST_FINAL, final)
                _, reason, final = Storage.describe({ reason = "newer_schema", at = 5, data = {} }, L, formatDate)
                assert.are.equal(L.REASON_NEWER, reason)
                assert.are.equal(L.DISCARD_FINAL, final)
            end)

            it("labels an entry that is not a table unknown and unreadable", function()
                local date, reason = Storage.describe(42, L, formatDate)
                assert.are.equal(L.DATE_UNKNOWN, date)
                assert.are.equal(L.REASON_UNREADABLE, reason)
                assert.is_false(Storage.restorable(42))
            end)

            it("gives an unknown date for a time that is not a finite number, or that the formatter refuses", function()
                local failing = function() error("out of range") end
                local returnsNil = function() return nil end
                for _, case in ipairs({
                    { "x", formatDate }, { 0 / 0, formatDate }, { math.huge, formatDate },
                    { 1e300, failing }, { 5, returnsNil },
                }) do
                    assert.are.equal(L.DATE_UNKNOWN, (Storage.describe({ reason = "lost", at = case[1] }, L, case[2])))
                end
            end)

            it("restores an entry whose date is unknown", function()
                local saved = savedTable()
                saved.schemaVersion = nil
                local db = Storage.load(saved, NOW)
                db.recovery[1].at = "x"
                assert.is_true(Storage.restorable(db.recovery[1]))
                assert.are.equal(L.DATE_UNKNOWN, (Storage.describe(db.recovery[1], L, formatDate)))
            end)
        end)
    end)
end)
