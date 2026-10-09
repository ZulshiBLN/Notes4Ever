local addonName, ns = ...

-- The EllesmereUI look, through EllesmereUI's public skinning API
-- (SKINNING_API.md in its folder). Whether it applies is EllesmereUI's
-- decision: it calls back only while its third-party skinning is on for this
-- addon - once at login, or live when the player turns it on. Turning it off
-- takes a /reload: EllesmereUI fades the template art and does not restore it.
--
-- An overlay on the Blizzard base (Skin.lua): it restyles what the base set
-- and leaves the rest - icons, expanders, highlight, grip - to it.
if not (EllesmereUI and EllesmereUI.RegisterSkin) then return end

local NAME = "EllesmereUI"

-- S.Font sets an explicit font and colour, keeping the size it finds. On
-- the client SetFontObject does not reset explicit values (probed on build
-- 70291), so a recycled row would keep a root's size and gold. Size and
-- colour are therefore read from the font object the base set: gold roots,
-- small white rows, the grey hint.
local function font(S, region)
    local object = region:GetFontObject()
    region:SetFont(object:GetFont())
    local r, g, b = object:GetTextColor()
    S.Font(region, r, g, b)
end

local function overlay(S)
    return {
        window = function(frame)
            S.Shell(frame)
            -- After the base hid the portrait, which lays the border out anew.
            S.FadeNineSlice(frame.NineSlice)
            S.Inset(frame.Inset)
            S.CloseButton(frame.CloseButton)
        end,

        scrollBar = function(bar)
            S.ScrollBar(bar)
        end,

        treeRow = function(button)
            font(S, button.label)
            -- Read on every row init, not cached: the accent changes live.
            local r, g, b = S.GetAccentColor()
            button.selection:SetColorTexture(r, g, b, 0.25)
        end,

        editor = function(_, editBox)
            font(S, editBox)
        end,

        hint = function(fontString)
            font(S, fontString)
        end,
    }
end

EllesmereUI.RegisterSkin(addonName, function(S)
    ns.Skin:Register(NAME, overlay(S))
    ns.Skin:Activate(NAME)
    -- Rows take the accent on init; a live accent change re-inits them.
    S.OnLooksChanged(function() ns.Tree.Refresh() end)
end)
