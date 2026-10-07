-- The notes model, outside the game. Model.lua calls no WoW function, so it
-- runs here exactly as it runs in the client; time comes in as an argument.

local addon = require("addon")

local function loadModel()
    return addon.load("Notes4Ever/Model.lua").Model
end

local NOW = 1000

-- Every id in a table, and whether any appears twice.
local function idsOf(db)
    local seen, duplicate, count = {}, nil, 0
    local function walk(node)
        if seen[node.id] then duplicate = node.id end
        seen[node.id] = true
        count = count + 1
        for _, child in ipairs(node.children or {}) do walk(child) end
    end
    walk(db.root)
    return seen, duplicate, count
end

-- A comparable picture of a subtree: titles, kinds, texts and shape, without
-- ids, which a move across roots is allowed to change.
local function shape(node)
    local out = { kind = node.kind, title = node.title, text = node.text }
    if node.children then
        out.children = {}
        for i, child in ipairs(node.children) do out.children[i] = shape(child) end
    end
    return out
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepCopy(v) end
    return out
end

describe("Model", function()
    local Model

    before_each(function()
        Model = loadModel()
    end)

    describe("a new table", function()
        it("holds one empty root folder", function()
            local db = Model.newTable(NOW)
            assert.are.equal("folder", db.root.kind)
            assert.are.same({}, db.root.children)
            assert.are.equal(NOW, db.root.created)
        end)
    end)

    describe("create", function()
        it("adds folders and pages under a folder, each with its own id", function()
            local db = Model.newTable(NOW)
            local folder = assert(Model.create(db, db.root.id, "folder", "Dungeons", NOW))
            local page = assert(Model.create(db, folder.id, "page", "Deadmines", NOW + 1))

            assert.are.equal(folder, db.root.children[1])
            assert.are.equal(page, folder.children[1])
            assert.are.equal("", page.text)
            assert.is_nil(page.children)
            assert.are.equal(NOW + 1, page.created)
            assert.are.equal(NOW + 1, page.modified)
            local _, duplicate = idsOf(db)
            assert.is_nil(duplicate)
        end)

        it("nests folders to any depth", function()
            local db = Model.newTable(NOW)
            local parent = db.root
            for depth = 1, 10 do
                parent = assert(Model.create(db, parent.id, "folder", "level " .. depth, NOW))
            end
            local _, _, count = idsOf(db)
            assert.are.equal(11, count)
        end)

        it("refuses a page as parent, an unknown parent and an unknown kind", function()
            local db = Model.newTable(NOW)
            local page = Model.create(db, db.root.id, "page", "p", NOW)
            local before = deepCopy(db)

            assert.is_nil(Model.create(db, page.id, "page", "inside a page", NOW))
            assert.is_nil(Model.create(db, 999, "page", "nowhere", NOW))
            assert.is_nil(Model.create(db, db.root.id, "picture", "x", NOW))
            assert.are.same(before, db)
        end)
    end)

    describe("rename and setText", function()
        it("change the node and its modified time, nothing else", function()
            local db = Model.newTable(NOW)
            local page = Model.create(db, db.root.id, "page", "old", NOW)

            assert.is_true(Model.rename(db, page.id, "new", NOW + 5))
            assert.is_true(Model.setText(db, page.id, "body", NOW + 6))
            assert.are.equal("new", page.title)
            assert.are.equal("body", page.text)
            assert.are.equal(NOW, page.created)
            assert.are.equal(NOW + 6, page.modified)
        end)

        it("refuse an empty or blank title", function()
            local db = Model.newTable(NOW)
            local page = Model.create(db, db.root.id, "page", "keep", NOW)
            assert.is_nil(Model.rename(db, page.id, "", NOW + 1))
            assert.is_nil(Model.rename(db, page.id, "   ", NOW + 1))
            assert.are.equal("keep", page.title)
            assert.are.equal(NOW, page.modified)
        end)

        it("refuse text on a folder", function()
            local db = Model.newTable(NOW)
            local folder = Model.create(db, db.root.id, "folder", "f", NOW)
            assert.is_nil(Model.setText(db, folder.id, "text", NOW))
            assert.is_nil(folder.text)
        end)
    end)

    describe("move within a root", function()
        it("moves the subtree and keeps its ids", function()
            local db = Model.newTable(NOW)
            local a = Model.create(db, db.root.id, "folder", "a", NOW)
            local b = Model.create(db, db.root.id, "folder", "b", NOW)
            local page = Model.create(db, a.id, "page", "p", NOW)
            Model.setText(db, page.id, "keep me", NOW)
            local id = page.id

            assert.is_table(Model.move(db, page.id, db, b.id, NOW + 1))
            assert.are.same({}, a.children)
            assert.are.equal(id, b.children[1].id)
            assert.are.equal("keep me", b.children[1].text)
        end)

        it("refuses a move into the node's own subtree, leaving the tree unchanged", function()
            local db = Model.newTable(NOW)
            local a = Model.create(db, db.root.id, "folder", "a", NOW)
            local inner = Model.create(db, a.id, "folder", "inner", NOW)
            local before = deepCopy(db)

            assert.is_nil(Model.move(db, a.id, db, a.id, NOW))
            assert.is_nil(Model.move(db, a.id, db, inner.id, NOW))
            assert.are.same(before, db)
        end)
    end)

    -- The editor follows a moved page by the node move returns: within a
    -- table that is the node itself, across tables the copy with new ids.
    describe("what move returns", function()
        it("is the node itself within a table", function()
            local db = Model.newTable(NOW)
            local folder = Model.create(db, db.root.id, "folder", "f", NOW)
            local page = Model.create(db, db.root.id, "page", "p", NOW)
            assert.are.equal(page, Model.move(db, page.id, db, folder.id, NOW))
        end)

        -- An editor showing a page deep inside a moved folder must find that
        -- page again; across tables every id in the subtree changes.
        it("comes with each old id's new id when the subtree changes tables", function()
            local account, character = Model.newTable(NOW), Model.newTable(NOW)
            for i = 1, 3 do Model.create(character, character.root.id, "page", "pad " .. i, NOW) end
            local folder = Model.create(account, account.root.id, "folder", "f", NOW)
            local inner = Model.create(account, folder.id, "folder", "inner", NOW)
            local page = Model.create(account, inner.id, "page", "deep", NOW)
            Model.setText(account, page.id, "keep", NOW)

            local _, ids = Model.move(account, folder.id, character, character.root.id, NOW)
            assert.are.equal("keep", Model.find(character, ids[page.id]).text)
            assert.are.equal("inner", Model.find(character, ids[inner.id]).title)
            assert.are.equal("f", Model.find(character, ids[folder.id]).title)
        end)

        it("comes with no id changes within a table", function()
            local db = Model.newTable(NOW)
            local folder = Model.create(db, db.root.id, "folder", "f", NOW)
            local page = Model.create(db, db.root.id, "page", "p", NOW)
            local _, ids = Model.move(db, page.id, db, folder.id, NOW)
            assert.is_nil(ids)
        end)

        it("is the copy in the target table across tables", function()
            local account, character = Model.newTable(NOW), Model.newTable(NOW)
            Model.create(character, character.root.id, "page", "taking an id", NOW)
            local page = Model.create(account, account.root.id, "page", "p", NOW)
            local moved = Model.move(account, page.id, character, character.root.id, NOW)
            assert.are.equal(moved, Model.find(character, moved.id))
            assert.are.equal("p", moved.title)
            assert.are_not.equal(page.id, moved.id)
        end)
    end)

    describe("move across roots", function()
        it("moves account -> character and back with subtree and text intact", function()
            local account, character = Model.newTable(NOW), Model.newTable(NOW)
            local folder = Model.create(account, account.root.id, "folder", "Routes", NOW)
            local page = Model.create(account, folder.id, "page", "Elwynn", NOW)
            Model.setText(account, page.id, "north road |cffff0000 äöü\nline two", NOW)
            local picture = shape(folder)

            assert.is_table(Model.move(account, folder.id, character, character.root.id, NOW + 1))
            assert.are.same({}, account.root.children)
            assert.are.same(picture, shape(character.root.children[1]))

            local moved = character.root.children[1]
            assert.is_table(Model.move(character, moved.id, account, account.root.id, NOW + 2))
            assert.are.same({}, character.root.children)
            assert.are.same(picture, shape(account.root.children[1]))
        end)

        it("keeps every id unique when two characters move notes into the account root", function()
            local account = Model.newTable(NOW)
            local alice, bob = Model.newTable(NOW), Model.newTable(NOW)

            -- Both characters' counters start alike, so their ids collide by design.
            for i = 1, 3 do
                local fa = Model.create(alice, alice.root.id, "folder", "alice " .. i, NOW)
                Model.create(alice, fa.id, "page", "a-page " .. i, NOW)
                local fb = Model.create(bob, bob.root.id, "folder", "bob " .. i, NOW)
                Model.create(bob, fb.id, "page", "b-page " .. i, NOW)
            end
            local expected = {}
            for _, db in ipairs({ alice, bob }) do
                for _, node in ipairs(db.root.children) do expected[#expected + 1] = shape(node) end
            end

            for _, db in ipairs({ alice, bob }) do
                while db.root.children[1] do
                    assert.is_table(Model.move(db, db.root.children[1].id, account, account.root.id, NOW))
                end
            end
            -- And one back and forth again, to churn the counters.
            local first = account.root.children[1]
            assert.is_table(Model.move(account, first.id, alice, alice.root.id, NOW))
            assert.is_table(Model.move(alice, alice.root.children[1].id, account, account.root.id, NOW))

            local _, duplicate, count = idsOf(account)
            assert.is_nil(duplicate)
            assert.are.equal(1 + 12, count)

            local found = {}
            for _, node in ipairs(account.root.children) do found[node.title] = shape(node) end
            for _, picture in ipairs(expected) do
                assert.are.same(picture, found[picture.title])
            end
        end)

        it("leaves the source untouched when the insert fails", function()
            local account, character = Model.newTable(NOW), Model.newTable(NOW)
            local page = Model.create(account, account.root.id, "page", "p", NOW)
            local target = Model.create(character, character.root.id, "page", "not a folder", NOW)
            local beforeAccount, beforeCharacter = deepCopy(account), deepCopy(character)

            assert.is_nil(Model.move(account, page.id, character, target.id, NOW))
            assert.is_nil(Model.move(account, page.id, character, 999, NOW))
            assert.are.same(beforeAccount, account)
            assert.are.same(beforeCharacter, character)
        end)
    end)

    describe("delete", function()
        it("removes exactly the subtree", function()
            local db = Model.newTable(NOW)
            local keep = Model.create(db, db.root.id, "folder", "keep", NOW)
            Model.create(db, keep.id, "page", "kept page", NOW)
            local gone = Model.create(db, db.root.id, "folder", "gone", NOW)
            Model.create(db, gone.id, "page", "gone page", NOW)
            local inner = Model.create(db, gone.id, "folder", "gone inner", NOW)
            Model.create(db, inner.id, "page", "deep", NOW)
            local keepPicture = shape(keep)

            assert.are.equal(4, Model.delete(db, gone.id))
            assert.are.equal(1, #db.root.children)
            assert.are.same(keepPicture, shape(db.root.children[1]))
            assert.is_nil(Model.find(db, gone.id))
        end)
    end)

    describe("roots", function()
        it("cannot be moved or deleted", function()
            local account, character = Model.newTable(NOW), Model.newTable(NOW)
            Model.create(account, account.root.id, "page", "p", NOW)
            local before = deepCopy(account)

            assert.is_nil(Model.delete(account, account.root.id))
            assert.is_nil(Model.move(account, account.root.id, character, character.root.id, NOW))
            assert.is_nil(Model.move(account, account.root.id, account, account.root.id, NOW))
            assert.are.same(before, account)
        end)
    end)
end)
