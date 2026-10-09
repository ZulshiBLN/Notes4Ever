-- The export format, outside the game: what export writes, what parse reads
-- back, what parse refuses, and how insert adds notes. Transfer.lua is
-- API-free; the rules are in plan 3's RESEARCH companion, Export format.

local addon = require("addon")

local NOW = 1000

local function loadAddon()
    local ns = {}
    addon.load("Notes4Ever/Model.lua", ns)
    addon.load("Notes4Ever/Transfer.lua", ns)
    return ns
end

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

local function lines(text)
    local out = {}
    for line in text:gmatch("([^\n]*)\n") do out[#out + 1] = line end
    return out
end

local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

describe("Transfer", function()
    local Model, Transfer

    before_each(function()
        local ns = loadAddon()
        Model, Transfer = ns.Model, ns.Transfer
    end)

    -- RESEARCH's title table: the node, the line export writes for it, and
    -- the title it reads back as - the same, except for the two rows whose
    -- trailing space export drops.
    local TITLES = {
        { "folder", "a/",   "# a//",    "a/" },
        { "page",   "a/",   "# a\\/",   "a/" },
        { "folder", "a\\",  "# a\\\\/", "a\\" },
        { "page",   "a\\",  "# a\\\\",  "a\\" },
        { "page",   "#1",   "# #1",     "#1" },
        { "page",   "a||b", "# a||b",   "a||b" },
        { "page",   "a\\/", "# a\\\\\\/", "a\\/" },
        { "folder", "a\\/", "# a\\\\//",  "a\\/" },
        { "page",   " a",   "#  a",     " a" },
        { "page",   "a/ ",  "# a\\/",   "a/" },
        { "folder", "a ",   "# a/",     "a" },
    }

    describe("titles", function()
        for _, row in ipairs(TITLES) do
            local kind, title, written, readBack = row[1], row[2], row[3], row[4]

            it("writes " .. kind .. " '" .. title .. "' as '" .. written .. "' and reads it back", function()
                local db = Model.newTable(NOW)
                local node = Model.create(db, db.root.id, kind, title, NOW)
                local text = Transfer.export(db, node.id)
                assert.is_true(contains(lines(text), written), text)

                local nodes = assert(Transfer.parse(text))
                assert.are.equal(1, #nodes)
                assert.are.equal(kind, nodes[1].kind)
                assert.are.equal(readBack, nodes[1].title)
            end)
        end
    end)

    describe("a whole tree", function()
        -- Every title row, page texts at their edges, and an empty folder last.
        local TEXTS = {
            "", "abc", "abc\n", "\n", "abc\n\n",
            "#heading\n\\path\n##", "a\n   \n\tb  ", "a||b äöü ß",
        }

        local function buildTree()
            local db = Model.newTable(NOW)
            local folder = Model.create(db, db.root.id, "folder", "Texts", NOW)
            for i, text in ipairs(TEXTS) do
                local page = Model.create(db, folder.id, "page", "Page " .. i, NOW)
                Model.setText(db, page.id, text, NOW)
            end
            for _, row in ipairs(TITLES) do
                local node = Model.create(db, db.root.id, row[1], row[2], NOW)
                if row[1] == "page" then Model.setText(db, node.id, "text of " .. row[2], NOW) end
            end
            local nested = Model.create(db, db.root.id, "folder", "Nested", NOW)
            local inner = Model.create(db, nested.id, "folder", "Inner", NOW)
            Model.create(db, inner.id, "page", "Deep", NOW)
            -- The last page ends in newlines, then an empty folder closes the export.
            local last = Model.create(db, db.root.id, "page", "Last", NOW)
            Model.setText(db, last.id, "ends\n\n", NOW)
            Model.create(db, db.root.id, "folder", "Empty", NOW)
            return db
        end

        -- What parse must give back: the tree, with the trailing-space titles
        -- as RESEARCH says they read back.
        local function expected(db)
            local readBack = {}
            for _, row in ipairs(TITLES) do readBack[row[2]] = row[4] end
            local out = shapes(db.root.children)
            for _, node in ipairs(out) do
                if readBack[node.title] then node.title = readBack[node.title] end
            end
            return out
        end

        it("reads back what the root's export wrote", function()
            local db = buildTree()
            local nodes = assert(Transfer.parse(Transfer.export(db, db.root.id)))
            assert.are.same(expected(db), shapes(nodes))
        end)

        it("exports a folder as itself, with its subtree", function()
            local db = buildTree()
            local folder = db.root.children[1]
            local nodes = assert(Transfer.parse(Transfer.export(db, folder.id)))
            assert.are.same({ shape(folder) }, shapes(nodes))
        end)

        it("starts with the header and ends every line with a newline", function()
            local db = buildTree()
            local text = Transfer.export(db, db.root.id)
            assert.are.equal("Notes4Ever export 1\n", text:sub(1, 20))
            assert.are.equal("\n", text:sub(-1))
        end)

        it("reads \\r\\n as \\n", function()
            local nodes = assert(Transfer.parse("Notes4Ever export 1\r\n# p\r\na\r\nb\r\n"))
            assert.are.equal("a\nb", nodes[1].text)
        end)

        it("reads an export that lost its final newline", function()
            local nodes = assert(Transfer.parse("Notes4Ever export 1\n# p\nabc"))
            assert.are.equal("abc", nodes[1].text)
        end)
    end)

    describe("the header", function()
        it("is read with trailing spaces and a leading zero", function()
            local nodes = assert(Transfer.parse("Notes4Ever export 01 \t\n# p\n"))
            assert.are.equal("p", nodes[1].title)
        end)

        it("ignores whitespace-only lines under a folder and before the first node", function()
            local nodes = assert(Transfer.parse("Notes4Ever export 1\n  \n# a/\n\t\n\n## b\n"))
            assert.are.equal("b", nodes[1].children[1].title)
        end)
    end)

    describe("refuses", function()
        local REFUSALS = {
            { "empty input",                     "",                                          "bad_header" },
            { "whitespace only",                 "  \n\t\n",                                  "bad_header" },
            { "another first line",              "Hello\n# p\n",                              "bad_header" },
            { "version zero",                    "Notes4Ever export 0\n# p\n",                "bad_header" },
            { "a version that is not a number",  "Notes4Ever export x\n# p\n",                "bad_header" },
            { "a newer version",                 "Notes4Ever export 2\n# p\n",                "newer_version" },
            { "# without a space",               "Notes4Ever export 1\n#p\n",                 "bad_node_line" },
            { "# and a space only",              "Notes4Ever export 1\n# \n",                 "bad_node_line" },
            { "a first node at depth 2",         "Notes4Ever export 1\n## p\n",               "depth_jump" },
            { "a jump of two",                   "Notes4Ever export 1\n# a/\n### p\n",        "depth_jump" },
            { "a node under a page",             "Notes4Ever export 1\n# p\n## c\n",          "child_of_page" },
            { "a blank title",                   "Notes4Ever export 1\n# /\n",                "blank_title" },
            { "text before the first node",      "Notes4Ever export 1\nx\n# p\n",             "text_outside_page" },
            { "text under a folder",             "Notes4Ever export 1\n# a/\ntext\n",         "text_outside_page" },
            { "a header with no node",           "Notes4Ever export 1\n",                     "empty" },
            { "a header with blank lines only",  "Notes4Ever export 1\n\n  \n",               "empty" },
            -- Where two reasons fit one line, the first in RESEARCH's order wins.
            { "a jump of two under a page",      "Notes4Ever export 1\n# p\n### c\n",         "depth_jump" },
            -- An earlier page still sits two levels down; only the depth check
            -- run first reports this jump as one.
            { "a jump onto an earlier page's level",
              "Notes4Ever export 1\n# a/\n## p\n# q/\n### x\n",                                "depth_jump" },
            { "a blank title under a page",      "Notes4Ever export 1\n# p\n## /\n",          "child_of_page" },
        }

        for _, case in ipairs(REFUSALS) do
            it(case[1] .. ": " .. case[3], function()
                local nodes, reason = Transfer.parse(case[2])
                assert.is_nil(nodes)
                assert.are.equal(case[3], reason)
            end)
        end
    end)

    -- Every reason the player can be shown has its text: read from the
    -- sources, so a reason added later without a key is caught.
    it("has an IMPORT_ locale key for every refusal reason", function()
        local L = addon.load("Notes4Ever/Locales/enUS.lua", {}).L_enUS
        local reasons = {}
        -- `return nil, "x"`, and the header check's own `return "x"`.
        local source = addon.read("Notes4Ever/Transfer.lua")
        for _, pattern in ipairs({ 'return nil, "([%w_]+)"', 'return "([%w_]+)"' }) do
            for reason in source:gmatch(pattern) do reasons[reason] = true end
        end
        -- Insert passes on what Model's folder lookup refuses.
        reasons.not_found, reasons.not_a_folder = true, true
        local count = 0
        for reason in pairs(reasons) do
            count = count + 1
            assert.is_string(L["IMPORT_" .. reason:upper()], reason)
        end
        assert.is_true(count >= 10)
    end)

    describe("insert", function()
        local function existing()
            local db = Model.newTable(NOW)
            local folder = Model.create(db, db.root.id, "folder", "Target", NOW)
            local page = Model.create(db, folder.id, "page", "Old", NOW)
            Model.setText(db, page.id, "kept", NOW)
            Model.create(db, db.root.id, "page", "Beside", NOW)
            return db, folder, page
        end

        local function deepCopy(t)
            if type(t) ~= "table" then return t end
            local out = {}
            for k, v in pairs(t) do out[k] = deepCopy(v) end
            return out
        end

        it("appends with fresh ids and timestamps, every earlier node unchanged and in order", function()
            local db, folder = existing()
            local before = deepCopy(db.root)
            local firstNewId = db.nextId
            local nodes = assert(Transfer.parse("Notes4Ever export 1\n# A/\n## B\ntext\n# C\n"))

            assert.is_truthy(Transfer.insert(db, folder.id, nodes, NOW + 5))

            -- The earlier child keeps its place and content; the new ones follow.
            assert.are.same(before.children[1].children[1], folder.children[1])
            assert.are.same(before.children[2], db.root.children[2])
            assert.are.equal(3, #folder.children)
            local a, c = folder.children[2], folder.children[3]
            assert.are.same({ kind = "folder", title = "A", children = {
                { kind = "page", title = "B", text = "text" } } }, shape(a))
            assert.are.same({ kind = "page", title = "C", text = "" }, shape(c))

            local ids = {}
            for _, node in ipairs({ a, a.children[1], c }) do
                assert.is_true(node.id >= firstNewId)
                assert.is_nil(ids[node.id])
                ids[node.id] = true
                assert.are.equal(NOW + 5, node.created)
                assert.are.equal(NOW + 5, node.modified)
            end
            assert.is_true(db.nextId > firstNewId + 2)
        end)

        it("refuses a target that is gone or is a page, changing nothing", function()
            local db, _, page = existing()
            local before = deepCopy(db)
            local nodes = assert(Transfer.parse("Notes4Ever export 1\n# p\n"))

            local ok, reason = Transfer.insert(db, 999, nodes, NOW)
            assert.is_nil(ok)
            assert.are.equal("not_found", reason)

            ok, reason = Transfer.insert(db, page.id, nodes, NOW)
            assert.is_nil(ok)
            assert.are.equal("not_a_folder", reason)
            assert.are.same(before, db)
        end)

        it("does not share tables with the parsed nodes", function()
            local db, folder = existing()
            local nodes = assert(Transfer.parse("Notes4Ever export 1\n# A/\n"))
            Transfer.insert(db, folder.id, nodes, NOW)
            Transfer.insert(db, folder.id, nodes, NOW)
            assert.are_not.equal(folder.children[2], folder.children[3])
            assert.are_not.equal(folder.children[2].children, folder.children[3].children)
        end)
    end)
end)
