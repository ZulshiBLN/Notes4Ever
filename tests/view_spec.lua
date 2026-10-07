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
