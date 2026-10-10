local addonName, ns = ...

local L, Skin, Format = ns.L, ns.Skin, ns.Format

-- The row of buttons above the page. Each button applies one of Format's
-- operations at the cursor through Editor.Apply; what an operation does is
-- Format's, so this file only builds buttons and menus.
local Toolbar = {}
ns.Toolbar = Toolbar

local HEIGHT = 22
local GAP = 4
-- Room around a button's label for the template's rounded ends.
local PADDING = 24

-- The Icon menu's groups, as ranges of Format.ICON_MENU.
local ICON_GROUPS = {
    { title = "ICONS_MARKERS", first = 1,  last = 8 },
    { title = "ICONS_QUESTS",  first = 9,  last = 10 },
    { title = "ICONS_COINS",   first = 11, last = 13 },
    { title = "ICONS_ROLES",   first = 14, last = 16 },
}

-- `arg` is the colour or icon; the line operations take none.
local function apply(operation, arg)
    ns.Editor.Apply(function(source, cursor) return operation(source, cursor, arg) end)
end

-- A colour's name shown in that colour, so the menu is its own swatch.
local function swatch(rgb, label)
    return "|cff" .. rgb .. label .. "|r"
end

local function showColourMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, menu)
        menu:CreateButton(L.COLOUR_DEFAULT, function() apply(Format.colour, nil) end)
        for _, colour in ipairs(Format.PALETTE) do
            menu:CreateButton(swatch(colour.rgb, L["COLOUR_" .. colour.name:upper()]),
                function() apply(Format.colour, colour.rgb) end)
        end
    end)
end

local function showIconMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, menu)
        for index, group in ipairs(ICON_GROUPS) do
            if index > 1 then menu:CreateDivider() end
            menu:CreateTitle(L[group.title])
            for i = group.first, group.last do
                local name = Format.ICON_MENU[i]
                menu:CreateButton(Format.iconCode(name) .. " " .. L["ICON_" .. name:upper()],
                    function() apply(Format.icon, name) end)
            end
        end
    end)
end

local function showTip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.label)
    GameTooltip:AddLine(button.tip, nil, nil, nil, true)
    GameTooltip:Show()
end

local function hideTip()
    GameTooltip:Hide()
end

-- Returns the toolbar's frame, one button high; the caller anchors it.
function Toolbar.Create(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(HEIGHT)

    local previous
    local function add(label, tip, onClick)
        local button = Skin:Apply("toolbarButton", CreateFrame("Button", nil, bar, "UIPanelButtonTemplate"))
        button.label, button.tip = label, tip
        button:SetText(label)
        button:SetSize(button:GetTextWidth() + PADDING, HEIGHT)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", GAP, 0)
        else
            button:SetPoint("LEFT")
        end
        button:SetScript("OnClick", onClick)
        button:SetScript("OnEnter", showTip)
        button:SetScript("OnLeave", hideTip)
        previous = button
    end

    add(L.TOOL_HEADING, L.TOOL_HEADING_TIP, function() apply(Format.heading) end)
    add(L.TOOL_COLOUR, L.TOOL_COLOUR_TIP, showColourMenu)
    add(L.TOOL_BULLET, L.TOOL_BULLET_TIP, function() apply(Format.bullet) end)
    add(L.TOOL_CHECKBOX, L.TOOL_CHECKBOX_TIP, function() apply(Format.checkbox) end)
    add(L.TOOL_ICON, L.TOOL_ICON_TIP, showIconMenu)
    return bar
end
