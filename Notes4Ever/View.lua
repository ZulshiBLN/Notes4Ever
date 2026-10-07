local addonName, ns = ...

-- What the window shows, worked out without WoW: API-free like the model, so
-- busted runs all of it. The frames in UI/ only draw what this returns.
local View = {}
ns.View = View

View.MIN_WIDTH = 400
View.MIN_HEIGHT = 300

View.DEFAULT_GEOMETRY = {
    point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 640, height = 420,
}

local POINTS = {
    CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

-- A finite number, or nil: NaN and infinities fail the comparisons below.
local function finite(value)
    if type(value) == "number" and value > -math.huge and value < math.huge then
        return value
    end
end

-- The stored window geometry, made safe to apply. Whatever is missing or
-- malformed takes its default - the field is a convenience and is never
-- trusted - and a size below the minimum is raised to it.
function View.geometry(ui)
    local d = View.DEFAULT_GEOMETRY
    if type(ui) ~= "table" then ui = {} end
    return {
        point         = POINTS[ui.point] and ui.point or d.point,
        relativePoint = POINTS[ui.relativePoint] and ui.relativePoint or d.relativePoint,
        x             = finite(ui.x) or d.x,
        y             = finite(ui.y) or d.y,
        width         = math.max(finite(ui.width) or d.width, View.MIN_WIDTH),
        height        = math.max(finite(ui.height) or d.height, View.MIN_HEIGHT),
    }
end
