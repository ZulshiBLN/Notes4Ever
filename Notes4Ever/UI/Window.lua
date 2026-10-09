local addonName, ns = ...

local L, View, Skin = ns.L, ns.View, ns.Skin

-- The notebook window: movable, resizable, closed by Escape. Its geometry is
-- stored in Notes4EverDB.ui and read back through View.geometry, which turns
-- whatever is stored into values safe to apply.
local Window = {}
ns.Window = Window

-- UISpecialFrames closes frames by name on Escape, so the frame needs one.
local FRAME_NAME = "Notes4EverWindow"

local frame

local function saveGeometry()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    Notes4EverDB.ui = {
        point = point, relativePoint = relativePoint, x = x, y = y,
        width = frame:GetWidth(), height = frame:GetHeight(),
    }
end

local function applyGeometry()
    local g = View.geometry(Notes4EverDB.ui)
    frame:ClearAllPoints()
    frame:SetPoint(g.point, UIParent, g.relativePoint, g.x, g.y)
    frame:SetSize(g.width, g.height)
end

-- Built on first use, after ADDON_LOADED, when Notes4EverDB exists.
local function build()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent, "ButtonFrameTemplate")
    Skin:Apply("window", frame)
    frame:SetTitle(L.WINDOW_TITLE)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)

    -- The position is ours to store; the client's layout cache would keep a
    -- second copy that could disagree with it.
    frame:SetMovable(true)
    frame:SetDontSavePosition(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        saveGeometry()
    end)

    -- Resized by hand rather than StartSizing, which moved the corner to the
    -- cursor - under EllesmereUI each click on the grip changed the size
    -- (plan 2, build 70245). The size follows the cursor's movement only.
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    Skin:Apply("resizeGrip", grip)
    grip:SetScript("OnMouseDown", function()
        -- Anchored at the top left while sizing, so only the corner moves.
        local left, top = frame:GetLeft(), frame:GetTop()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        local scale = frame:GetEffectiveScale()
        local x, y = GetCursorPosition()
        local start = { x = x / scale, y = y / scale,
                        width = frame:GetWidth(), height = frame:GetHeight() }
        grip:SetScript("OnUpdate", function()
            local cx, cy = GetCursorPosition()
            frame:SetSize(View.dragSize(start, cx / scale, cy / scale))
        end)
    end)
    grip:SetScript("OnMouseUp", function()
        grip:SetScript("OnUpdate", nil)
        saveGeometry()
    end)

    -- ButtonFrameTemplate's inset is the content area below the title: the
    -- tree on the left, the editor beside it.
    local content = frame.Inset or frame
    ns.Tree.Create(content)
    ns.Editor.Create(content, ns.Tree.WIDTH + 24)
    frame:SetScript("OnShow", ns.Tree.Refresh)
    -- Closing the window is a flush trigger: nothing typed waits for a timer.
    frame:SetScript("OnHide", ns.Editor.Flush)

    tinsert(UISpecialFrames, FRAME_NAME)
    frame:Hide()
    applyGeometry()
end

-- The notebook frame, for dialogs that close with it; nil before first use.
function Window.Frame()
    return frame
end

function Window.Toggle()
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
end
