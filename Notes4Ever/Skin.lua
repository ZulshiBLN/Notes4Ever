local addonName, ns = ...

-- The seam between the window code and how it looks. Window code names a
-- role - "window", "treeRow" - and the skins decide what that looks like.
-- Only files in Skins/ style frames; a source check enforces it.
-- An optional UI suite is reached only through its public skinning API, and
-- named only in its own adapter, Skins/<Suite>.lua - the source check and
-- luacheck refuse it anywhere else, so the addon works the same without it.
--
-- Blizzard is the base and styles every frame. Another skin is an overlay on
-- top: it may restyle what the base set, but never has to provide it again -
-- icons, expanders, grip textures stay the base's work.
local Skin = { skins = {}, base = "Blizzard", active = "Blizzard" }
ns.Skin = Skin

-- Each styled frame's role and the arguments of its last Apply, so that an
-- overlay activated later - EllesmereUI calls back at login, or when the
-- player turns it on - reaches frames built before it.
local applied = {}
-- Overlay roles that already reported an error: a broken row style would
-- otherwise report once per row on every refresh.
local reported = {}

function Skin:Register(name, roles)
    self.skins[name] = roles
end

local function style(self, role, frame, args)
    local base = self.skins[self.base][role]
    if base then base(frame, unpack(args, 1, args.n)) end
    if self.active == self.base then return end

    -- The overlay is someone else's code: the boundary where a failure is
    -- caught. The frame keeps its base style and whatever the overlay did
    -- before failing.
    local overlay = self.skins[self.active][role]
    if not overlay then return end
    local ok, err = pcall(overlay, frame, unpack(args, 1, args.n))
    if not ok and not reported[role] then
        reported[role] = true
        geterrorhandler()(err)
    end
end

-- Styles `frame` for `role` and returns the frame. Anything after the frame
-- - a tree row's state, say - is passed on to the skins. A role no skin
-- knows leaves the frame as created.
function Skin:Apply(role, frame, ...)
    local args = { n = select("#", ...), ... }
    applied[frame] = { role = role, args = args }
    style(self, role, frame, args)
    return frame
end

-- Makes a registered overlay active and restyles every frame styled so far.
function Skin:Activate(name)
    self.active = name
    for frame, last in pairs(applied) do style(self, last.role, frame, last.args) end
end
