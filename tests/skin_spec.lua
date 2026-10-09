-- The skin seam: Blizzard as the base, an overlay on top, frames remembered
-- so an overlay arriving late - EllesmereUI calls back at login or when the
-- player turns it on - still reaches every frame built before.

local addon = require("addon")

-- A fresh seam per test, with a recording error handler.
local function newSeam()
    local errors = {}
    local env = {
        geterrorhandler = function()
            return function(err) errors[#errors + 1] = err end
        end,
    }
    local ns = addon.load("Notes4Ever/Skin.lua", {}, env)
    return ns.Skin, errors
end

-- A skin whose roles record each call as "<skin>:<role>:<frame>:<args>".
local function recorder(log, skinName, roles)
    local skin = {}
    for _, role in ipairs(roles) do
        skin[role] = function(frame, ...)
            log[#log + 1] = table.concat({ skinName, role, frame.name, ... }, ":")
        end
    end
    return skin
end

local function frame(name) return { name = name } end

describe("Skin", function()
    local Skin, errors, log

    before_each(function()
        Skin, errors = newSeam()
        log = {}
        Skin:Register(Skin.base, recorder(log, "base", { "window", "treeRow" }))
    end)

    it("applies the base alone while no overlay is active", function()
        local f = frame("f")
        assert.are.equal(f, Skin:Apply("treeRow", f, "a", "b"))
        assert.are.same({ "base:treeRow:f:a:b" }, log)
        assert.are.equal(Skin.base, Skin.active)
    end)

    it("applies the base, then the active overlay", function()
        Skin:Register("Over", recorder(log, "over", { "treeRow" }))
        Skin:Activate("Over")
        Skin:Apply("treeRow", frame("f"), "a")
        assert.are.same({ "base:treeRow:f:a", "over:treeRow:f:a" }, log)
    end)

    it("gives a role the overlay lacks the base only", function()
        Skin:Register("Over", recorder(log, "over", { "treeRow" }))
        Skin:Activate("Over")
        Skin:Apply("window", frame("w"))
        assert.are.same({ "base:window:w" }, log)
    end)

    it("leaves a frame whose role neither skin has", function()
        Skin:Register("Over", recorder(log, "over", { "treeRow" }))
        Skin:Activate("Over")
        local bar = frame("bar")
        assert.are.equal(bar, Skin:Apply("scrollBar", bar))
        assert.are.same({}, log)
    end)

    it("re-applies every remembered frame once, with its last arguments, on Activate", function()
        local row, window = frame("row"), frame("window")
        Skin:Apply("treeRow", row, "first")
        Skin:Apply("treeRow", row, "second")
        Skin:Apply("window", window)
        Skin:Register("Over", recorder(log, "over", { "treeRow", "window" }))
        for i = #log, 1, -1 do log[i] = nil end

        Skin:Activate("Over")

        table.sort(log)
        assert.are.same({
            "base:treeRow:row:second", "base:window:window",
            "over:treeRow:row:second", "over:window:window",
        }, log)
        assert.are.equal("Over", Skin.active)
    end)

    it("reports an overlay's error once per role and still returns the frame with its base style", function()
        Skin:Register("Over", {
            treeRow = function() error("treeRow broke") end,
            window = function() error("window broke") end,
        })
        Skin:Activate("Over")

        local a, b = frame("a"), frame("b")
        assert.are.equal(a, Skin:Apply("treeRow", a))
        assert.are.equal(b, Skin:Apply("treeRow", b))
        Skin:Apply("window", frame("w"))

        assert.are.same({ "base:treeRow:a", "base:treeRow:b", "base:window:w" }, log)
        assert.are.equal(2, #errors)
        assert.truthy(tostring(errors[1]):find("treeRow broke", 1, true))
        assert.truthy(tostring(errors[2]):find("window broke", 1, true))
    end)
end)
