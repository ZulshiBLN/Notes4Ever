-- Format.lua: the toolbar's operations on a page's text and cursor, and the
-- visible text search matches. API-free; the rules are plan 4a's RESEARCH,
-- part 2, and the cases its "The cases the criteria name", criterion 1.
--
-- A test text marks the cursor with `^`: "ab^c" is "abc" with the cursor
-- after "ab", at byte 2 - the edit box counts raw bytes, codes included
-- (probe 1). Results are shown the same way.

local addon = require("addon")

local function loadFormat()
    return addon.load("Notes4Ever/Format.lua").Format
end

local function at(marked)
    local i = marked:find("^", 1, true)
    return marked:sub(1, i - 1) .. marked:sub(i + 1), i - 1
end

local function show(text, cursor)
    return text:sub(1, cursor) .. "^" .. text:sub(cursor + 1)
end

describe("Format", function()
    local Format
    -- Codes, from Format's own tables rather than retyped.
    local R, G, GOLD, E
    local HEAD, BOX, CHECKED, SKULL, STAR
    local BULLET = "\226\128\162"

    -- Applies `op` to a marked text and returns the marked result.
    local function apply(op, marked, ...)
        local text, cursor = at(marked)
        local newText, newCursor = Format[op](text, cursor, ...)
        return show(newText, newCursor)
    end

    before_each(function()
        Format = loadFormat()
        R = "|cff" .. Format.rgb("red")
        G = "|cff" .. Format.rgb("green")
        GOLD = "|cff" .. Format.rgb("gold")
        E = "|r"
        HEAD = Format.iconCode("heading")
        BOX = Format.iconCode("box")
        CHECKED = Format.iconCode("checked")
        SKULL = Format.iconCode("skull")
        STAR = Format.iconCode("star")
    end)

    describe("its tables", function()
        it("hold the palette and icons RESEARCH names, in its order", function()
            local names = {}
            for i, colour in ipairs(Format.PALETTE) do names[i] = colour.name end
            assert.are.same({ "red", "orange", "gold", "green", "blue", "purple", "grey" }, names)
            assert.are.equal("ff2020", Format.rgb("red"))
            assert.are.equal("ffd100", Format.rgb("gold"))
            assert.are.equal("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t", SKULL)
            assert.are.equal("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:0:19:22:41|t",
                Format.iconCode("tank"))
        end)

        it("list sixteen icons for the menu, not heading, box and checked", function()
            assert.are.same({ "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull",
                              "quest", "turnin", "gold", "silver", "copper", "tank", "healer", "damage" },
                            Format.ICON_MENU)
        end)
    end)

    describe("colour", function()
        -- Cases 2: the cursor right after, before and inside a word.
        it("colours the word the cursor is right after, the cursor after its colour end", function()
            assert.are.equal(R .. "ab" .. E .. "^ cd", apply("colour", "ab^ cd", Format.rgb("red")))
        end)

        it("colours the word the cursor is right before, the cursor before its colour start", function()
            assert.are.equal("ab ^" .. R .. "cd" .. E, apply("colour", "ab ^cd", Format.rgb("red")))
        end)

        it("colours the word the cursor is inside, the cursor after the same letter", function()
            assert.are.equal(R .. "a^b" .. E, apply("colour", "a^b", Format.rgb("red")))
        end)

        it("colours a word with an umlaut and one with a typed |cff as text", function()
            assert.are.equal(R .. "\195\164" .. E .. "^", apply("colour", "\195\164^", Format.rgb("red")))
            assert.are.equal("x " .. R .. "||cffff2020y" .. E .. "^",
                apply("colour", "x ||cffff2020y^", Format.rgb("red")))
        end)

        -- Case 3: an icon at a word's edge keeps the default placement.
        it("colours a word with an icon at each edge, the icons outside the run", function()
            local word = SKULL .. "boss" .. SKULL
            assert.are.equal(SKULL .. R .. "boss" .. E .. SKULL .. "^",
                apply("colour", word .. "^", Format.rgb("red")))
            assert.are.equal("^" .. SKULL .. R .. "boss" .. E .. SKULL,
                apply("colour", "^" .. word, Format.rgb("red")))
        end)

        -- Case 5: a word inside a run of several splits the run.
        it("colours the first, a middle and the last word of a run", function()
            local run = R .. "one two three" .. E
            local function marked(word)
                return (run:gsub(word, word:sub(1, 2) .. "^" .. word:sub(3), 1))
            end
            assert.are.equal(G .. "on^e" .. E .. R .. " two three" .. E,
                apply("colour", marked("one"), Format.rgb("green")))
            assert.are.equal(R .. "one " .. E .. G .. "tw^o" .. E .. R .. " three" .. E,
                apply("colour", marked("two"), Format.rgb("green")))
            assert.are.equal(R .. "one two " .. E .. G .. "th^ree" .. E,
                apply("colour", marked("three"), Format.rgb("green")))
        end)

        it("gives a word Default", function()
            assert.are.equal("a b^", apply("colour", "a " .. R .. "b^" .. E, nil))
        end)

        -- Case 4: a pending colour between words.
        it("starts a pending colour between words, the cursor inside it", function()
            assert.are.equal("a " .. R .. "^" .. E .. " b", apply("colour", "a ^ b", Format.rgb("red")))
        end)

        it("changes a pending colour, and Default removes it", function()
            local pending = "a " .. R .. "^" .. E .. " b"
            assert.are.equal("a " .. G .. "^" .. E .. " b", apply("colour", pending, Format.rgb("green")))
            assert.are.equal("a ^ b", apply("colour", pending, nil))
        end)

        it("does nothing for Default between words outside a run", function()
            assert.are.equal("a ^ b", apply("colour", "a ^ b", nil))
        end)

        -- Case 6: Default and a pending colour inside a run.
        it("starts a pending Default inside a run, splitting it around the cursor", function()
            assert.are.equal(R .. "one " .. E .. "^" .. R .. " two" .. E,
                apply("colour", R .. "one ^ two" .. E, nil))
        end)

        it("starts a pending colour inside a run, splitting it around the cursor", function()
            assert.are.equal(R .. "one " .. E .. G .. "^" .. E .. R .. " two" .. E,
                apply("colour", R .. "one ^ two" .. E, Format.rgb("green")))
        end)

        -- Case 7: a colour in a pending Default.
        it("turns a pending Default into a pending colour; the run's own colour removes it", function()
            local pendingDefault = R .. "one " .. E .. "^" .. R .. " two" .. E
            assert.are.equal(R .. "one " .. E .. G .. "^" .. E .. R .. " two" .. E,
                apply("colour", pendingDefault, Format.rgb("green")))
            assert.are.equal(R .. "one ^ two" .. E, apply("colour", pendingDefault, Format.rgb("red")))
            assert.are.equal(pendingDefault, apply("colour", pendingDefault, nil))
        end)

        -- Case 11: the four-code pending colour is read as a colour.
        it("reads a pending colour inside a run as a colour, so Default makes it a pending Default", function()
            local pendingGreen = R .. "one " .. E .. G .. "^" .. E .. R .. " two" .. E
            assert.are.equal(R .. "one " .. E .. "^" .. R .. " two" .. E, apply("colour", pendingGreen, nil))
        end)

        -- Ninth review, hint 1: the run's own colour in a pending colour.
        it("removes a pending colour inside a run when the run's own colour is pressed", function()
            local pendingGreen = R .. "one " .. E .. G .. "^" .. E .. R .. " two" .. E
            assert.are.equal(R .. "one ^ two" .. E, apply("colour", pendingGreen, Format.rgb("red")))
        end)

        -- Case 12: the run's own colour between words inside it.
        it("does nothing when a run's own colour is pressed between words inside it", function()
            assert.are.equal(R .. "one ^ two" .. E, apply("colour", R .. "one ^ two" .. E, Format.rgb("red")))
        end)

        it("does nothing on a heading line or inside a prefix", function()
            local heading = HEAD .. " " .. GOLD .. "Ro^ute" .. E
            assert.are.equal(heading, apply("colour", heading, Format.rgb("red")))
            assert.are.equal(BULLET .. "^ abc", apply("colour", BULLET .. "^ abc", Format.rgb("red")))
        end)
    end)

    describe("pending codes", function()
        -- Case 10.
        it("keeps a pending code at the cursor and drops one elsewhere", function()
            assert.are.equal(BULLET .. " a " .. R .. "^" .. E .. " b",
                apply("bullet", "a " .. R .. "^" .. E .. " b"))
            assert.are.equal(BULLET .. " a  b^", apply("bullet", "a " .. R .. E .. " b^"))
        end)

        -- Case 9.
        it("carries a pending colour when Bullet moves the cursor on an empty line", function()
            local red = apply("colour", "^", Format.rgb("red"))
            assert.are.equal(R .. "^" .. E, red)
            assert.are.equal(BULLET .. " " .. R .. "^" .. E, apply("bullet", red))
        end)

        -- Case 20.
        it("drops a pending colour when its line becomes a heading", function()
            assert.are.equal(HEAD .. " " .. GOLD .. "^" .. E, apply("heading", R .. "^" .. E))
        end)

        -- Case 8.
        it("moves a pending colour past an icon inserted into it", function()
            assert.are.equal("a " .. SKULL .. R .. "^" .. E .. " b",
                apply("icon", "a " .. R .. "^" .. E .. " b", "skull"))
        end)

        -- A pending Default must be read, not re-derived: only an operation
        -- that moves it shows the difference.
        it("moves a pending Default past an icon inserted into it", function()
            assert.are.equal(R .. "one " .. SKULL .. E .. "^" .. R .. " two" .. E,
                apply("icon", R .. "one " .. E .. "^" .. R .. " two" .. E, "skull"))
        end)
    end)

    describe("icon", function()
        it("inserts an icon at the cursor, the cursor after it", function()
            assert.are.equal("a" .. STAR .. "^b", apply("icon", "a^b", "star"))
        end)

        -- Case 13.
        it("inserts an icon inside a run without breaking it", function()
            assert.are.equal(R .. "one " .. SKULL .. "^ two" .. E,
                apply("icon", R .. "one ^ two" .. E, "skull"))
        end)

        -- Case 15.
        it("keeps a heading's gold over an icon added at its end", function()
            assert.are.equal(HEAD .. " " .. GOLD .. "Route" .. SKULL .. "^" .. E,
                apply("icon", HEAD .. " " .. GOLD .. "Route^" .. E, "skull"))
        end)

        -- Case 22: a byte inside a unit counts as the gap before it.
        it("counts a cursor inside a character, a || or an icon as the gap before it", function()
            local text = "a\195\164||" .. SKULL
            local function insertAt(cursor)
                local newText, newCursor = Format.icon(text, cursor, "star")
                return show(newText, newCursor)
            end
            assert.are.equal("a" .. STAR .. "^\195\164||" .. SKULL, insertAt(2))
            assert.are.equal("a\195\164" .. STAR .. "^||" .. SKULL, insertAt(4))
            assert.are.equal("a\195\164||" .. STAR .. "^" .. SKULL, insertAt(5 + 3))
        end)
    end)

    describe("line operations", function()
        -- Case 14.
        it("makes an empty line an empty heading, the cursor inside its gold", function()
            assert.are.equal(HEAD .. " " .. GOLD .. "^" .. E, apply("heading", "^"))
        end)

        it("keeps an empty heading's gold while the cursor is elsewhere, and after it comes back", function()
            local lines = "x^\n" .. HEAD .. " " .. GOLD .. E
            assert.are.equal(BULLET .. " x^\n" .. HEAD .. " " .. GOLD .. E, apply("bullet", lines))
            assert.are.equal(HEAD .. " " .. GOLD .. "^" .. E,
                apply("colour", HEAD .. " ^" .. GOLD .. E, Format.rgb("red")))
        end)

        -- Case 17: Heading, Bullet and Checkbox at the line's start, inside the prefix, mid-line.
        it("adds a heading with the cursor at the start, inside a prefix and mid-line", function()
            assert.are.equal(HEAD .. " " .. GOLD .. "^abc" .. E, apply("heading", "^abc"))
            assert.are.equal(HEAD .. " " .. GOLD .. "^abc" .. E, apply("heading", BULLET .. "^ abc"))
            assert.are.equal(HEAD .. " " .. GOLD .. "ab^c" .. E, apply("heading", "ab^c"))
        end)

        it("removes a heading, its gold too", function()
            assert.are.equal("ab^c", apply("heading", HEAD .. " " .. GOLD .. "ab^c" .. E))
            assert.are.equal("^abc", apply("heading", HEAD .. "^ " .. GOLD .. "abc" .. E))
        end)

        it("adds and removes a bullet", function()
            assert.are.equal(BULLET .. " ^abc", apply("bullet", "^abc"))
            assert.are.equal(BULLET .. " ab^c", apply("bullet", "ab^c"))
            assert.are.equal("ab^c", apply("bullet", BULLET .. " ab^c"))
            assert.are.equal("^abc", apply("bullet", BULLET .. "^ abc"))
        end)

        it("adds a box at the start and mid-line", function()
            assert.are.equal(BOX .. " ^abc", apply("checkbox", "^abc"))
            assert.are.equal(BOX .. " ab^c", apply("checkbox", "ab^c"))
        end)

        it("switches one kind to another", function()
            assert.are.equal(BULLET .. " ab^c", apply("bullet", HEAD .. " " .. GOLD .. "ab^c" .. E))
            assert.are.equal(BOX .. " ab^c", apply("checkbox", BULLET .. " ab^c"))
        end)

        -- Case 18.
        it("cycles a checkbox from none to box to checked to box", function()
            local box = apply("checkbox", "abc^")
            assert.are.equal(BOX .. " abc^", box)
            local checked = apply("checkbox", box)
            assert.are.equal(CHECKED .. " abc^", checked)
            assert.are.equal(BOX .. " abc^", apply("checkbox", checked))
        end)

        it("keeps a cursor next to a swapped box next to the new one", function()
            assert.are.equal(CHECKED .. "^ abc", apply("checkbox", BOX .. "^ abc"))
        end)

        -- Ninth review, hints 2 and 3: the gap before a prefix is the line's
        -- start, not inside the prefix, so the spec's rows apply there - and
        -- what is put before the prefix ends the line's kind.
        it("starts a pending colour before a prefix, at the line's start", function()
            assert.are.equal(R .. "^" .. E .. BULLET .. " abc",
                apply("colour", "^" .. BULLET .. " abc", Format.rgb("red")))
        end)

        it("ends a line's kind when an icon goes before its prefix", function()
            assert.are.equal(STAR .. "^" .. BULLET .. " abc", apply("icon", "^" .. BULLET .. " abc", "star"))
            -- The line is no kind now, so Bullet adds a new prefix in front.
            assert.are.equal(BULLET .. " " .. STAR .. BULLET .. " ab^c", apply("bullet", STAR .. BULLET .. " ab^c"))
        end)

        -- Case 21.
        it("writes a prefix in a colour back without it", function()
            assert.are.equal(BULLET .. " " .. R .. "abc" .. E .. SKULL .. "^",
                apply("icon", R .. BULLET .. " abc^" .. E, "skull"))
        end)
    end)

    describe("tidying", function()
        -- Case 16, with probe 9's unclosed colour.
        it("drops a lone |, and the | bytes of an icon not in the table", function()
            assert.are.equal(BULLET .. " a x b^", apply("bullet", "a |x b^"))
            assert.are.equal(BULLET .. " a TInterface\\Foo:0t b^",
                apply("bullet", "a |TInterface\\Foo:0|t b^"))
        end)

        it("closes a colour left open at the line's end", function()
            assert.are.equal(BULLET .. " a " .. R .. "ro^" .. E, apply("bullet", "a " .. R .. "ro^"))
        end)

        it("closes a run at a line end and opens it again on the next", function()
            -- Bullet acts on the cursor's line, the second.
            assert.are.equal(R .. "a" .. E .. "\n" .. BULLET .. " " .. R .. "b^" .. E,
                apply("bullet", R .. "a\nb^" .. E))
        end)
    end)

    -- Colour is read as the client shows it (probes 4 and 10): a stack that
    -- |cff pushes and |r pops, carried across line ends.
    describe("the colour stack", function()
        -- Case 24.
        it("reads probe 4's nested colours as the client shows them, and writes them unnested", function()
            assert.are.equal(R .. "a" .. E .. G .. "b" .. E .. R .. "c" .. E .. STAR .. "^",
                apply("icon", R .. "a" .. G .. "b" .. E .. "c" .. E .. "^", "star"))
        end)

        -- Case 25.
        it("carries an unclosed colour across a line end, one closed run per line", function()
            assert.are.equal(R .. "ab" .. E .. "\n" .. R .. "cd" .. E .. STAR .. "^",
                apply("icon", R .. "ab\ncd^", "star"))
        end)

        -- Case 26.
        it("ignores an |r on an empty stack", function()
            assert.are.equal("a" .. R .. "b" .. E .. STAR .. "^",
                apply("icon", "a" .. E .. R .. "b" .. E .. "^", "star"))
        end)
    end)

    describe("plain", function()
        -- Case 19.
        it("removes every code kind and keeps ||", function()
            assert.are.equal("ro||x y\nz", Format.plain(R .. "ro" .. E .. SKULL .. "||x |y\n" .. GOLD .. "z"))
        end)
    end)
end)
