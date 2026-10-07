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

    frame:SetResizable(true)
    frame:SetResizeBounds(View.MIN_WIDTH, View.MIN_HEIGHT)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    Skin:Apply("resizeGrip", grip)
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        saveGeometry()
    end)

    tinsert(UISpecialFrames, FRAME_NAME)
    frame:Hide()
    applyGeometry()
end

function Window.Toggle()
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
end
