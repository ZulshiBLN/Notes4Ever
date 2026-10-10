-- The export format, outside the game: what export writes, what parse reads
-- back, what parse refuses, and how insert adds notes. Transfer.lua is
-- API-free; version 1's rules are in plan 3's RESEARCH companion, Export
-- format, version 2's in plan 4a's RESEARCH, Export format version 2.

local addon = require("addon")

local NOW = 1000

-- Format before Transfer, as the TOC loads them.
local function loadAddon()
    local ns = {}
    addon.load("Notes4Ever/Model.lua", ns)
    addon.load("Notes4Ever/Format.lua", ns)
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
            assert.are.equal("Notes4Ever export 2\n", text:sub(1, 20))
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
            { "a newer version",                 "Notes4Ever export 3\n# p\n",                "newer_version" },
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

    -- Version 2: page text lines carry Notes4Ever's codes as tokens.
    -- Criterion 2's cases 1 to 6; codes and names come from Format.
    describe("version 2 page text", function()
        local Format, R, E

        before_each(function()
            Format = loadAddon().Format
            R, E = "|cff" .. Format.rgb("red"), "|r"
        end)

        -- The page's text lines as export wrote them.
        local function written(text)
            local db = Model.newTable(NOW)
            local page = Model.create(db, db.root.id, "page", "P", NOW)
            Model.setText(db, page.id, text, NOW)
            local out = lines(Transfer.export(db, page.id))
            return { unpack(out, 3) }
        end

        local function roundTrip(text)
            local db = Model.newTable(NOW)
            local page = Model.create(db, db.root.id, "page", "P", NOW)
            Model.setText(db, page.id, text, NOW)
            local nodes = assert(Transfer.parse(Transfer.export(db, page.id)))
            return nodes[1].text
        end

        local function parsed(textLines)
            local nodes, reason = Transfer.parse("Notes4Ever export 2\n# P\n" .. textLines .. "\n")
            return nodes and nodes[1].text, reason
        end

        -- Case 1.
        it("gives back every code, unbalanced colours and codes at a line's start", function()
            local texts = {
                R .. "red" .. E .. " plain",
                R .. "open, never closed",
                "closed, never opened" .. E,
                E .. R .. "\n" .. R .. "at line starts" .. E,
                "# a near-miss heading\n#also",
                "a typed ||cffff2020 stays text",
                "|cff123abcoutside the palette|r",
            }
            for _, colour in ipairs(Format.PALETTE) do
                texts[#texts + 1] = "|cff" .. colour.rgb .. colour.name .. E
            end
            local names = { "heading", "box", "checked" }
            for _, name in ipairs(Format.ICON_MENU) do names[#names + 1] = name end
            for _, name in ipairs(names) do
                texts[#texts + 1] = "a " .. Format.iconCode(name) .. " b" .. Format.iconCode(name)
            end
            for _, text in ipairs(texts) do
                assert.are.equal(text, roundTrip(text))
            end
        end)

        it("writes colours, ends and icons as tokens", function()
            assert.are.same({ "{red}x{/} {icon:skull}" },
                written(R .. "x" .. E .. " " .. Format.iconCode("skull")))
        end)

        -- Case 2.
        it("escapes a backslash, a brace, a backslash before a token, and # or \\ at a line's start", function()
            assert.are.same({ "a\\\\b" }, written("a\\b"))
            -- The written `\{` starts with `\`, so it gets one more.
            assert.are.same({ "\\\\{x}" }, written("{x}"))
            assert.are.same({ "a\\{x}" }, written("a{x}"))
            assert.are.same({ "a\\\\{red}" }, written("a\\" .. R))
            assert.are.same({ "\\#x", "\\\\\\y" }, written("#x\n\\y"))
            for _, text in ipairs({ "a\\b", "{x}", "a\\" .. R .. "b" .. E, "#x\n\\y", "\\{red}" }) do
                assert.are.equal(text, roundTrip(text))
            end
        end)

        -- Case 3.
        it("writes a colour outside the palette as {#rrggbb} and reads uppercase hex as lowercase", function()
            assert.are.same({ "{#123abc}x" }, written("|cff123abcx"))
            assert.are.equal("|cffabcdefx", (parsed("{#ABCDEF}x")))
        end)

        -- Case 4.
        it("writes a lone | as ||, one left from an icon outside the table too", function()
            assert.are.same({ "a||b" }, written("a|b"))
            assert.are.same({ "||TInterface\\\\Nope:0||t" }, written("|TInterface\\Nope:0|t"))
            assert.are.equal("a||b", roundTrip("a|b"))
        end)

        -- Case 5.
        it("refuses an unknown token, an uppercase name, an unknown icon, an empty token, a short hex and an open brace", function()
            for _, line in ipairs({ "{nope}", "{Red}", "{icon:nope}", "{}", "{#12345}", "a {red" }) do
                local text, reason = parsed(line)
                assert.is_nil(text, line)
                assert.are.equal("bad_markup", reason, line)
            end
        end)

        -- Case 6; version 3 is in the refusals above.
        it("still reads version 1, where braces are text", function()
            local nodes = assert(Transfer.parse("Notes4Ever export 1\n# P\n{red}x\\y\n"))
            assert.are.equal("{red}x\\y", nodes[1].text)
        end)
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
