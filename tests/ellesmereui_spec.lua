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
                                 "ScrollBar", "Font" }) do
        S[primitive] = function(target, ...)
            calls[#calls + 1] = table.concat({ primitive, target.name, ... }, ":")
        end
    end
    function S.GetAccentColor() return ACCENT[1], ACCENT[2], ACCENT[3] end
    function S.OnLooksChanged(fn) S.looks[#S.looks + 1] = fn end
    return S
end

-- A text region whose colour is what the base set.
local function text(name, r, g, b)
    return { name = name, GetTextColor = function() return r, g, b, 1 end }
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

        it("gives the scroll bar EllesmereUI's", function()
            overlay.scrollBar({ name = "bar" })
            assert.are.same({ "ScrollBar:bar" }, calls)
        end)

        it("re-fonts a row's label in the colour the base gave it, the selection in the accent", function()
            local colour
            local button = {
                label = text("label", 1, 0.82, 0),
                selection = { SetColorTexture = function(_, r, g, b) colour = { r, g, b } end },
            }
            overlay.treeRow(button, { isRoot = true })
            assert.are.same({ "Font:label:1:0.82:0" }, calls)
            assert.are.same(ACCENT, colour)
        end)

        it("re-fonts the edit box, not its scroll frame, and the hint in their colours", function()
            overlay.editor({ name = "scrollFrame" }, text("editBox", 1, 1, 1))
            overlay.hint(text("hint", 0.5, 0.5, 0.5))
            assert.are.same({ "Font:editBox:1:1:1", "Font:hint:0.5:0.5:0.5" }, calls)
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
