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
