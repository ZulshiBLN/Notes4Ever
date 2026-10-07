local addonName, ns = ...

-- The seam between the window code and how it looks. Window code names a
-- role - "window", "resizeGrip" - and the active skin decides what that
-- looks like. Only files in Skins/ style frames; a source check enforces it.
-- Plan 2 adds skins for EllesmereUI and ElvUI and a way to choose.
local Skin = { skins = {}, active = "Blizzard" }
ns.Skin = Skin

function Skin:Register(name, roles)
    self.skins[name] = roles
end

-- Styles `frame` for `role` with the active skin, and returns the frame. A
-- role the skin does not know is left as created.
function Skin:Apply(role, frame)
    local skin = self.skins[self.active]
    local style = skin and skin[role]
    if style then style(frame) end
    return frame
end
