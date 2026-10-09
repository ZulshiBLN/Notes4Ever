-- View.lua: what the window shows, worked out without WoW. The frames only
-- draw what these functions return.

local addon = require("addon")

local function loadView()
    local ns = {}
    addon.load("Notes4Ever/Model.lua", ns)
    addon.load("Notes4Ever/View.lua", ns)
    return ns.View
end

describe("View.geometry", function()
    local View

    before_each(function()
        View = loadView()
    end)

    it("gives the defaults when nothing is stored", function()
        assert.are.same(View.DEFAULT_GEOMETRY, View.geometry(nil))
    end)

    it("gives the defaults for a ui that is not a table", function()
        for _, ui in ipairs({ "garbage", 42, true }) do
            assert.are.same(View.DEFAULT_GEOMETRY, View.geometry(ui))
        end
    end)

    it("keeps valid stored values", function()
        local ui = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 12.5, y = -40,
                     width = 700, height = 500 }
        assert.are.same(ui, View.geometry(ui))
    end)

    it("replaces each malformed value with its default, keeping the rest", function()
        local ui = { point = "NOWHERE", relativePoint = "CENTER", x = "far", y = 0 / 0,
                     width = {}, height = 480 }
        local g = View.geometry(ui)
        assert.are.equal(View.DEFAULT_GEOMETRY.point, g.point)
        assert.are.equal("CENTER", g.relativePoint)
        assert.are.equal(View.DEFAULT_GEOMETRY.x, g.x)
        assert.are.equal(View.DEFAULT_GEOMETRY.y, g.y)
        assert.are.equal(View.DEFAULT_GEOMETRY.width, g.width)
        assert.are.equal(480, g.height)
    end)

    it("raises a size below the minimum to the minimum", function()
        local g = View.geometry({ width = 10, height = 10 })
        assert.are.equal(View.MIN_WIDTH, g.width)
        assert.are.equal(View.MIN_HEIGHT, g.height)
    end)

    it("never hands out the stored table itself", function()
        local ui = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 640, height = 420 }
        assert.are_not.equal(ui, View.geometry(ui))
    end)
end)

-- Resizing from the grip: the size follows the cursor's movement since the
-- grip was pressed, never its position - with StartSizing the corner jumped
-- to the cursor under EllesmereUI (plan 2, in game on 70291).
describe("View.dragSize", function()
    local View

    before_each(function()
        View = loadView()
    end)

    -- Cursor coordinates grow rightwards and upwards, as on the client.
    local start = { x = 900, y = 120, width = 700, height = 500 }

    it("keeps the size while the cursor has not moved, wherever on the grip it was pressed", function()
        assert.are.same({ 700, 500 }, { View.dragSize(start, 900, 120) })
        -- The same window pressed elsewhere: only movement counts.
        local elsewhere = { x = 1310, y = 655, width = 700, height = 500 }
        assert.are.same({ 700, 500 }, { View.dragSize(elsewhere, 1310, 655) })
    end)

    it("grows right and down with the cursor, shrinks left and up", function()
        assert.are.same({ 730, 540 }, { View.dragSize(start, 930, 80) })
        assert.are.same({ 650, 480 }, { View.dragSize(start, 850, 140) })
    end)

    it("stops at the minimum size", function()
        assert.are.same({ View.MIN_WIDTH, View.MIN_HEIGHT }, { View.dragSize(start, 0, 2000) })
    end)
end)

describe("View.rows", function()
    local View, Model
    local NOW = 3000
    local LABELS = { account = "Account notes", character = "Character notes" }

    before_each(function()
        local ns = {}
        addon.load("Notes4Ever/Model.lua", ns)
        addon.load("Notes4Ever/View.lua", ns)
        View, Model = ns.View, ns.Model
    end)

    local function titles(rows)
        local out = {}
        for i, row in ipairs(rows) do out[i] = string.rep("  ", row.depth) .. row.title end
        return out
    end

    it("shows both roots, account first, with their labels", function()
        local rows = View.rows(Model.newTable(NOW), Model.newTable(NOW), {}, LABELS)
        assert.are.same({ "Account notes", "Character notes" }, titles(rows))
        assert.are.equal("account", rows[1].table)
        assert.are.equal("character", rows[2].table)
        assert.are.equal(0, rows[1].depth)
    end)

    it("lists a root's notes in stored order beneath it, folders collapsed until opened", function()
        local account, character = Model.newTable(NOW), Model.newTable(NOW)
        local dungeons = Model.create(account, account.root.id, "folder", "Dungeons", NOW)
        Model.create(account, dungeons.id, "page", "Deadmines", NOW)
        Model.create(account, account.root.id, "page", "Todo", NOW)
        Model.create(character, character.root.id, "page", "Bank", NOW)

        assert.are.same({ "Account notes", "  Dungeons", "  Todo", "Character notes", "  Bank" },
                        titles(View.rows(account, character, {}, LABELS)))

        local expanded = {}
        View.toggle(expanded, View.rows(account, character, expanded, LABELS)[2])
        assert.are.same({ "Account notes", "  Dungeons", "    Deadmines", "  Todo",
                          "Character notes", "  Bank" },
                        titles(View.rows(account, character, expanded, LABELS)))
    end)

    it("hides a whole subtree under a collapsed folder, however deep", function()
        local account = Model.newTable(NOW)
        local a = Model.create(account, account.root.id, "folder", "a", NOW)
        local b = Model.create(account, a.id, "folder", "b", NOW)
        Model.create(account, b.id, "page", "c", NOW)

        local expanded = {}
        local rows = View.rows(account, Model.newTable(NOW), expanded, LABELS)
        View.toggle(expanded, rows[2])                 -- open a
        rows = View.rows(account, Model.newTable(NOW), expanded, LABELS)
        View.toggle(expanded, rows[3])                 -- open b
        assert.are.equal(5, #View.rows(account, Model.newTable(NOW), expanded, LABELS))

        View.toggle(expanded, rows[2])                 -- close a again
        assert.are.same({ "Account notes", "  a", "Character notes" },
                        titles(View.rows(account, Model.newTable(NOW), expanded, LABELS)))
    end)

    it("lets a root be collapsed too", function()
        local account = Model.newTable(NOW)
        Model.create(account, account.root.id, "page", "p", NOW)
        local expanded = {}
        View.toggle(expanded, View.rows(account, Model.newTable(NOW), expanded, LABELS)[1])
        assert.are.same({ "Account notes", "Character notes" },
                        titles(View.rows(account, Model.newTable(NOW), expanded, LABELS)))
    end)

    it("marks what can be opened, and whether it is open", function()
        local account = Model.newTable(NOW)
        local full = Model.create(account, account.root.id, "folder", "full", NOW)
        Model.create(account, full.id, "page", "p", NOW)
        Model.create(account, account.root.id, "folder", "empty", NOW)
        Model.create(account, account.root.id, "page", "page", NOW)

        local rows = View.rows(account, Model.newTable(NOW), {}, LABELS)
        assert.is_true(rows[1].hasChildren and rows[1].expanded)
        assert.is_true(rows[2].hasChildren)
        assert.is_false(rows[2].expanded)
        assert.is_false(rows[3].hasChildren)
        assert.are.equal("page", rows[4].kind)
        assert.is_false(rows[4].hasChildren)
    end)

    it("builds row keys the way View.key does, so callers can find a row", function()
        local account = Model.newTable(NOW)
        local page = Model.create(account, account.root.id, "page", "p", NOW)
        local rows = View.rows(account, Model.newTable(NOW), {}, LABELS)
        assert.are.equal(View.key("account", page.id), rows[2].key)
    end)

    it("keys rows uniquely across the two tables, whose ids overlap", function()
        local account, character = Model.newTable(NOW), Model.newTable(NOW)
        Model.create(account, account.root.id, "page", "a", NOW)
        Model.create(character, character.root.id, "page", "c", NOW)
        local seen = {}
        for _, row in ipairs(View.rows(account, character, {}, LABELS)) do
            assert.is_nil(seen[row.key], row.key)
            seen[row.key] = true
        end
        assert.are.equal(4, (function() local n = 0 for _ in pairs(seen) do n = n + 1 end return n end)())
    end)
end)

describe("View.moveTargets", function()
    local View, Model
    local NOW = 3000
    local LABELS = { account = "Account notes", character = "Character notes" }

    before_each(function()
        local ns = {}
        addon.load("Notes4Ever/Model.lua", ns)
        addon.load("Notes4Ever/View.lua", ns)
        View, Model = ns.View, ns.Model
    end)

    local function names(targets)
        local out = {}
        for i, t in ipairs(targets) do out[i] = string.rep("  ", t.depth) .. t.title end
        return out
    end

    -- account: a/ (a1/ (deep page)), b/, page   character: c/
    local function fixture()
        local account, character = Model.newTable(NOW), Model.newTable(NOW)
        local a = Model.create(account, account.root.id, "folder", "a", NOW)
        local a1 = Model.create(account, a.id, "folder", "a1", NOW)
        Model.create(account, a1.id, "page", "deep page", NOW)
        Model.create(account, account.root.id, "folder", "b", NOW)
        local page = Model.create(account, account.root.id, "page", "page", NOW)
        Model.create(character, character.root.id, "folder", "c", NOW)
        return account, character, a, page
    end

    it("offers every folder of both roots, roots included, and no pages", function()
        local account, character, _, page = fixture()
        assert.are.same({ "Account notes", "  a", "    a1", "  b", "Character notes", "  c" },
                        names(View.moveTargets(account, character, "account", page.id, LABELS)))
    end)

    it("leaves out the node itself and its whole subtree", function()
        local account, character, a = fixture()
        assert.are.same({ "Account notes", "  b", "Character notes", "  c" },
                        names(View.moveTargets(account, character, "account", a.id, LABELS)))
    end)

    it("keeps a folder in the other table that shares the moving node's id", function()
        local account, character = Model.newTable(NOW), Model.newTable(NOW)
        local mine = Model.create(account, account.root.id, "folder", "mine", NOW)
        local twin = Model.create(character, character.root.id, "folder", "twin", NOW)
        assert.are.equal(mine.id, twin.id)
        assert.are.same({ "Account notes", "Character notes", "  twin" },
                        names(View.moveTargets(account, character, "account", mine.id, LABELS)))
    end)

    it("says which table and id each target is", function()
        local account, character, _, page = fixture()
        local targets = View.moveTargets(account, character, "account", page.id, LABELS)
        assert.are.equal("character", targets[5].table)
        assert.are.equal(character.root.id, targets[5].id)
    end)

    it("offers nothing for a root, which cannot move", function()
        local account, character = fixture()
        assert.is_nil(View.moveTargets(account, character, "account", account.root.id, LABELS))
    end)
end)

describe("View.deleteSummary", function()
    local View, Model
    local NOW = 3000

    before_each(function()
        local ns = {}
        addon.load("Notes4Ever/Model.lua", ns)
        addon.load("Notes4Ever/View.lua", ns)
        View, Model = ns.View, ns.Model
    end)

    it("counts the folders and pages a delete removes, the node included", function()
        local db = Model.newTable(NOW)
        local gone = Model.create(db, db.root.id, "folder", "gone", NOW)
        Model.create(db, gone.id, "page", "p1", NOW)
        local inner = Model.create(db, gone.id, "folder", "inner", NOW)
        Model.create(db, inner.id, "page", "p2", NOW)
        Model.create(db, db.root.id, "page", "kept", NOW)

        assert.are.same({ title = "gone", folders = 2, pages = 2 }, View.deleteSummary(db, gone.id))
    end)

    it("counts a single page as one page", function()
        local db = Model.newTable(NOW)
        local page = Model.create(db, db.root.id, "page", "p", NOW)
        assert.are.same({ title = "p", folders = 0, pages = 1 }, View.deleteSummary(db, page.id))
    end)

    it("matches what Model.delete then removes", function()
        local db = Model.newTable(NOW)
        local gone = Model.create(db, db.root.id, "folder", "gone", NOW)
        Model.create(db, gone.id, "page", "p", NOW)
        local summary = View.deleteSummary(db, gone.id)
        assert.are.equal(summary.folders + summary.pages, Model.delete(db, gone.id))
    end)

    it("offers nothing for a root, which cannot be deleted", function()
        local db = Model.newTable(NOW)
        assert.is_nil(View.deleteSummary(db, db.root.id))
    end)
end)

-- The editor's pending text: typed into the box, written to the model on a
-- flush - after a pause, on hiding, on changing page, before a tree action,
-- at logout. Whatever the trigger, these rules hold.
describe("View editor", function()
    local View, Model
    local NOW = 4000

    before_each(function()
        local ns = {}
        addon.load("Notes4Ever/Model.lua", ns)
        addon.load("Notes4Ever/View.lua", ns)
        View, Model = ns.View, ns.Model
    end)

    local function setup()
        local tables = { account = Model.newTable(NOW), character = Model.newTable(NOW) }
        local page = Model.create(tables.account, tables.account.root.id, "page", "p", NOW)
        Model.setText(tables.account, page.id, "saved", NOW)
        local editor = View.newEditor()
        return tables, page, editor
    end

    it("shows the page's text when opened", function()
        local tables, page, editor = setup()
        assert.are.equal("saved", View.editorOpen(editor, tables, "account", page.id, NOW))
    end)

    it("writes typed text once per flush, and nothing when nothing changed", function()
        local tables, page, editor = setup()
        View.editorOpen(editor, tables, "account", page.id, NOW)
        View.editorType(editor, "typed")
        assert.is_true(View.editorFlush(editor, tables, NOW + 1))
        assert.are.equal("typed", page.text)
        assert.are.equal(NOW + 1, page.modified)

        assert.is_false(View.editorFlush(editor, tables, NOW + 2))
        assert.are.equal(NOW + 1, page.modified)
    end)

    it("writes the previous page's text before opening another", function()
        local tables, page, editor = setup()
        local other = Model.create(tables.account, tables.account.root.id, "page", "o", NOW)
        View.editorOpen(editor, tables, "account", page.id, NOW)
        View.editorType(editor, "for p")
        View.editorOpen(editor, tables, "account", other.id, NOW + 1)
        assert.are.equal("for p", page.text)
        assert.are.equal("", other.text)
    end)

    it("writes nothing after its page was deleted, and closes", function()
        local tables, page, editor = setup()
        View.editorOpen(editor, tables, "account", page.id, NOW)
        View.editorType(editor, "too late")
        Model.delete(tables.account, page.id)
        assert.is_false(View.editorFlush(editor, tables, NOW + 1))
        assert.is_nil(View.editorPage(editor))
    end)

    -- Found in game: a deleted page stayed in the editor when nothing had
    -- been typed, and text typed into that ghost would have been dropped.
    it("closes after its page was deleted even when nothing was typed", function()
        local tables, page, editor = setup()
        View.editorOpen(editor, tables, "account", page.id, NOW)
        Model.delete(tables.account, page.id)
        assert.is_false(View.editorFlush(editor, tables, NOW + 1))
        assert.is_nil(View.editorPage(editor))
    end)

    it("follows its page to the new id when the page moves to the other table", function()
        local tables, page, editor = setup()
        View.editorOpen(editor, tables, "account", page.id, NOW)
        View.editorType(editor, "before the move")
        View.editorFlush(editor, tables, NOW)            -- every tree action flushes first

        local moved, ids = Model.move(tables.account, page.id, tables.character, tables.character.root.id, NOW)
        View.editorFollow(editor, "account", "character", ids)
        View.editorType(editor, "after the move")
        assert.is_true(View.editorFlush(editor, tables, NOW + 1))

        assert.are.same({ table = "character", id = moved.id }, View.editorPage(editor))
        assert.are.equal("after the move", moved.text)
    end)

    it("follows its page when a folder holding it moves to the other table", function()
        local tables, _, editor = setup()
        local folder = Model.create(tables.account, tables.account.root.id, "folder", "f", NOW)
        local deep = Model.create(tables.account, folder.id, "page", "deep", NOW)
        View.editorOpen(editor, tables, "account", deep.id, NOW)

        local _, ids = Model.move(tables.account, folder.id, tables.character, tables.character.root.id, NOW)
        View.editorFollow(editor, "account", "character", ids)
        View.editorType(editor, "still found")
        assert.is_true(View.editorFlush(editor, tables, NOW + 1))
        assert.are.equal("still found", Model.find(tables.character, ids[deep.id]).text)
    end)

    it("keeps its page through a move within one table", function()
        local tables, page, editor = setup()
        local folder = Model.create(tables.account, tables.account.root.id, "folder", "f", NOW)
        View.editorOpen(editor, tables, "account", page.id, NOW)
        local _, ids = Model.move(tables.account, page.id, tables.account, folder.id, NOW)
        View.editorFollow(editor, "account", "account", ids)
        View.editorType(editor, "same id")
        assert.is_true(View.editorFlush(editor, tables, NOW + 1))
        assert.are.equal("same id", page.text)
    end)

    it("ignores a move that does not involve its page", function()
        local tables, page, editor = setup()
        local other = Model.create(tables.account, tables.account.root.id, "page", "o", NOW)
        View.editorOpen(editor, tables, "account", page.id, NOW)
        local _, ids = Model.move(tables.account, other.id, tables.character, tables.character.root.id, NOW)
        View.editorFollow(editor, "account", "character", ids)
        assert.are.same({ table = "account", id = page.id }, View.editorPage(editor))
    end)
end)

-- Searching the tree: View.rows with a query. The rules are in plan 3's
-- RESEARCH, UI details, Searching.
describe("View.rows with a query", function()
    local View, Model
    local NOW = 4000
    local LABELS = { account = "Account notes", character = "Character notes" }

    before_each(function()
        local ns = {}
        addon.load("Notes4Ever/Model.lua", ns)
        addon.load("Notes4Ever/View.lua", ns)
        View, Model = ns.View, ns.Model
    end)

    local function titles(rows)
        local out = {}
        for i, row in ipairs(rows) do out[i] = string.rep("  ", row.depth) .. row.title end
        return out
    end

    local function page(db, parentId, title, text)
        local node = Model.create(db, parentId, "page", title, NOW)
        Model.setText(db, node.id, text, NOW)
        return node
    end

    -- Account: Dungeons/ { Deadmines "VanCleef", Stockade "Hogger" },
    -- Recipes/ { Bread "flour" }, Pipes "a||b" (as the edit box stores a
    -- typed a|b), Spaced "a b", Paren "(x", Literal "%(.";
    -- Character: Bank "gold".
    local function tree()
        local account, character = Model.newTable(NOW), Model.newTable(NOW)
        local dungeons = Model.create(account, account.root.id, "folder", "Dungeons", NOW)
        page(account, dungeons.id, "Deadmines", "VanCleef")
        page(account, dungeons.id, "Stockade", "Hogger")
        local recipes = Model.create(account, account.root.id, "folder", "Recipes", NOW)
        page(account, recipes.id, "Bread", "flour")
        page(account, account.root.id, "Pipes", "a||b")
        page(account, account.root.id, "Spaced", "a b")
        page(account, account.root.id, "Paren", "(x")
        page(account, account.root.id, "Literal", "%(.")
        page(character, character.root.id, "Bank", "gold")
        return account, character
    end

    local function search(query, expanded)
        local account, character = tree()
        return View.rows(account, character, expanded or {}, LABELS, query)
    end

    it("finds a page by title, with its folders open", function()
        assert.are.same({ "Account notes", "  Dungeons", "    Deadmines", "Character notes" },
                        titles(search("Deadmines")))
        local rows = search("Deadmines")
        assert.is_true(rows[1].expanded)
        assert.is_true(rows[2].expanded)
    end)

    it("finds a page by its text, in another case", function()
        assert.are.same({ "Account notes", "  Dungeons", "    Stockade", "Character notes" },
                        titles(search("hOGGER")))
    end)

    it("finds a folder by title, with its whole subtree", function()
        assert.are.same({ "Account notes", "  Dungeons", "    Deadmines", "    Stockade",
                          "Character notes" },
                        titles(search("dungeon")))
    end)

    it("finds a page storing a||b by the query a||b, not one storing a b", function()
        assert.are.same({ "Account notes", "  Pipes", "Character notes" }, titles(search("a||b")))
    end)

    it("matches %(. only literally, and does not find (x by it", function()
        assert.are.same({ "Account notes", "  Literal", "Character notes" }, titles(search("%(.")))
    end)

    it("matches the query as typed, untrimmed", function()
        assert.are.same({ "Account notes", "  Spaced", "Character notes" }, titles(search(" b")))
    end)

    it("shows a root without matches closed, with no rows under it", function()
        local rows = search("gold")
        assert.are.same({ "Account notes", "Character notes", "  Bank" }, titles(rows))
        assert.is_false(rows[1].expanded)
        assert.is_false(rows[1].hasChildren)
        assert.is_true(rows[2].expanded)
    end)

    it("does not match the roots' labels", function()
        assert.are.same({ "Account notes", "Character notes" }, titles(search("notes")))
    end)

    it("marks its rows, so a folder click changes nothing", function()
        for _, row in ipairs(search("Dead")) do assert.is_true(row.searching) end
        local account, character = tree()
        for _, row in ipairs(View.rows(account, character, {}, LABELS)) do assert.is_nil(row.searching) end
    end)

    it("gives today's rows for an empty or all-space query, and leaves expand state alone", function()
        local account, character = tree()
        local expanded = { [View.key("account", account.root.children[2].id)] = true }
        local before = {}
        for k, v in pairs(expanded) do before[k] = v end
        local today = View.rows(account, character, expanded, LABELS)
        for _, query in ipairs({ "", "   ", "\t" }) do
            assert.are.same(today, View.rows(account, character, expanded, LABELS, query))
        end
        View.rows(account, character, expanded, LABELS, "Dead")
        assert.are.same(before, expanded)
    end)
end)
