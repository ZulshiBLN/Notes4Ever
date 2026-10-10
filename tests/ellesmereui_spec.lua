-- The EllesmereUI adapter against a stub of EllesmereUI's public API: what
-- it registers, what it activates, and which primitive each role calls.
-- Whether the result looks right is checked in game (plan 2, criteria 1-3).

local addon = require("addon")

local ADAPTER = "Notes4Ever/Skins/EllesmereUI.lua"

-- Loads the seam, the base and the adapter as the TOC does, with `suite` as
-- the EllesmereUI global (nil: not installed).
local function loadWith(suite)
    local ns = {}
    local env = { geterrorhandler = function() return error end, EllesmereUI = suite }
    addon.load("Notes4Ever/Skin.lua", ns, env)
    addon.load("Notes4Ever/Skins/Blizzard.lua", ns, env)
    addon.load(ADAPTER, ns, env)
    return ns
end

-- A suite stub that keeps what RegisterSkin was given.
local function newSuite()
    local suite = { registered = {} }
    function suite.RegisterSkin(name, apply) suite.registered[name] = apply end
    return suite
end

-- A facade stub recording each primitive call as "<primitive>:<first arg's
-- name>" plus any further arguments.
local ACCENT = { 0.1, 0.2, 0.3 }
local function newFacade(calls)
    local S = { looks = {} }
    for _, primitive in ipairs({ "Shell", "FadeNineSlice", "Inset", "CloseButton",
                                 "ScrollBar", "Font", "EditBox", "Button" }) do
        S[primitive] = function(target, ...)
            calls[#calls + 1] = table.concat({ primitive, target.name, ... }, ":")
        end
    end
    function S.GetAccentColor() return ACCENT[1], ACCENT[2], ACCENT[3] end
    function S.OnLooksChanged(fn) S.looks[#S.looks + 1] = fn end
    return S
end

-- A text region the base gave the font object with colour r, g, b - but
-- still carrying the explicit size and gold of a root row it was before,
-- as a recycled row does: on the client SetFontObject does not reset an
-- explicit SetFont or SetTextColor (probed on build 70291). The region logs
-- into `calls` like the facade, so the order shows.
local function text(calls, name, r, g, b)
    local object = {
        GetFont = function() return "base.ttf", 10, "" end,
        GetTextColor = function() return r, g, b, 1 end,
    }
    return {
        name = name,
        GetFontObject = function() return object end,
        GetTextColor = function() return 1, 0.82, 0, 1 end,
        SetFont = function(_, path, size)
            calls[#calls + 1] = table.concat({ "SetFont", name, path, size }, ":")
        end,
    }
end

describe("EllesmereUI adapter", function()
    it("does nothing without EllesmereUI or without its RegisterSkin", function()
        for _, suite in ipairs({ false, {} }) do
            local ns = loadWith(suite or nil)
            assert.are.equal(ns.Skin.base, ns.Skin.active)
            local names = {}
            for name in pairs(ns.Skin.skins) do names[#names + 1] = name end
            assert.are.same({ ns.Skin.base }, names)
        end
    end)

    it("registers under the addon's name and waits for the callback", function()
        local suite = newSuite()
        local ns = loadWith(suite)
        assert.is_function(suite.registered.Notes4Ever)
        assert.are.equal(ns.Skin.base, ns.Skin.active)
    end)

    describe("once EllesmereUI calls back", function()
        local ns, S, calls, overlay

        before_each(function()
            local suite = newSuite()
            ns = loadWith(suite)
            calls = {}
            S = newFacade(calls)
            suite.registered.Notes4Ever(S)
            overlay = ns.Skin.skins[ns.Skin.active]
        end)

        it("makes its overlay the active skin", function()
            assert.are_not.equal(ns.Skin.base, ns.Skin.active)
            assert.is_table(overlay)
        end)

        it("gives the window the shell, a faded border, the inset and the close glyph", function()
            local window = { name = "window", NineSlice = { name = "nine" },
                             Inset = { name = "inset" }, CloseButton = { name = "close" } }
            overlay.window(window)
            assert.are.same({ "Shell:window", "FadeNineSlice:nine", "Inset:inset",
                              "CloseButton:close" }, calls)
        end)

        it("gives the scroll bar EllesmereUI's, over a faint track that stays with nothing to scroll", function()
            local track = { name = "track" }
            local textures = {}
            local bar = { name = "bar", Track = track }
            function bar.CreateTexture(_, _, layer)
                local t = { layer = layer, points = {} }
                function t:SetColorTexture(r, g, b, a) self.colour = { r, g, b, a } end
                function t:SetWidth(w) self.width = w end
                function t:SetPoint(point, relative) self.points[point] = relative end
                textures[#textures + 1] = t
                return t
            end
            overlay.scrollBar(bar)
            assert.are.same({ "ScrollBar:bar" }, calls)
            assert.are.equal(1, #textures)
            local t = textures[1]
            -- EllesmereUI fades the track and draws the thumb alone; the
            -- track must sit below it and run the track's full length.
            assert.are.equal("BACKGROUND", t.layer)
            assert.are.same({ TOP = track, BOTTOM = track }, t.points)
            assert.is_true(t.width > 0)
            assert.is_true(t.colour[4] > 0)
        end)

        it("re-fonts a reused row at its base font's size and colour, the selection in the accent", function()
            local colour
            local button = {
                label = text(calls, "label", 1, 1, 1),
                selection = { SetColorTexture = function(_, r, g, b) colour = { r, g, b } end },
            }
            overlay.treeRow(button, { isRoot = false })
            -- The size reset comes first: S.Font keeps whatever size it finds.
            assert.are.same({ "SetFont:label:base.ttf:10", "Font:label:1:1:1" }, calls)
            assert.are.same(ACCENT, colour)
        end)

        it("re-fonts the edit box, not its scroll frame, and the hint at their base fonts", function()
            overlay.editor({ name = "scrollFrame" }, text(calls, "editBox", 1, 1, 1))
            overlay.hint(text(calls, "hint", 0.5, 0.5, 0.5))
            assert.are.same({
                "SetFont:editBox:base.ttf:10", "Font:editBox:1:1:1",
                "SetFont:hint:base.ttf:10", "Font:hint:0.5:0.5:0.5",
            }, calls)
        end)

        -- The export and import dialog looks like the window: the same shell,
        -- border and inset, the suite's button, and the edit box and reason
        -- line re-fonted at their base fonts. Its scroll bar takes the
        -- scrollBar role, so it is not styled here.
        it("gives the dialog the window's shell, the button, and re-fonts box and reason", function()
            local dialog = { name = "dialog", NineSlice = { name = "nine" },
                             Inset = { name = "inset" }, CloseButton = { name = "close" } }
            overlay.dialog(dialog, text(calls, "editBox", 1, 1, 1), { name = "accept" },
                           text(calls, "reason", 1, 0.1, 0.1))
            assert.are.same({
                "Shell:dialog", "FadeNineSlice:nine", "Inset:inset", "CloseButton:close",
                "Button:accept",
                "SetFont:editBox:base.ttf:10", "Font:editBox:1:1:1",
                "SetFont:reason:base.ttf:10", "Font:reason:1:0.1:0.1",
            }, calls)
        end)

        -- S.EditBox fades every texture of the box, the magnifier too; the
        -- overlay shows it again, and re-fonts the box at its base font.
        it("gives the search box the suite's edit box, keeps its magnifier, re-fonts it", function()
            local alpha
            local box = text(calls, "search", 1, 1, 1)
            box.searchIcon = { SetAlpha = function(_, a) alpha = a end }
            overlay.searchBox(box)
            assert.are.same({ "EditBox:search", "SetFont:search:base.ttf:10", "Font:search:1:1:1" },
                            calls)
            assert.are.equal(1, alpha)
        end)

        it("gives a toolbar button the suite's button", function()
            overlay.toolbarButton({ name = "heading" })
            assert.are.same({ "Button:heading" }, calls)
        end)

        it("leaves the resize grip to the base", function()
            assert.is_nil(overlay.resizeGrip)
        end)

        it("refreshes the tree when EllesmereUI's looks change", function()
            local refreshed = 0
            ns.Tree = { Refresh = function() refreshed = refreshed + 1 end }
            assert.are.equal(1, #S.looks)
            S.looks[1]()
            assert.are.equal(1, refreshed)
        end)
    end)
end)
