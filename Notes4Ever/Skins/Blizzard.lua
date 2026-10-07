local addonName, ns = ...

-- The default look: the game's own. ButtonFrameTemplate already draws a
-- Blizzard window, so the skin mostly leaves it be.
ns.Skin:Register("Blizzard", {
    window = function(frame)
        -- A portrait slot with nothing in it; the template's helper hides it.
        if ButtonFrameTemplate_HidePortrait then
            ButtonFrameTemplate_HidePortrait(frame)
        end
    end,

    -- `row` is View.rows' row: its depth, whether it is a root, and whether a
    -- folder with children is open. Tree.lua has placed the parts.
    treeRow = function(button, row)
        button.label:SetFontObject(row.isRoot and GameFontNormal or GameFontHighlightSmall)
        button.expander:SetTexture(row.expanded
            and "Interface\\Buttons\\UI-MinusButton-Up"
            or "Interface\\Buttons\\UI-PlusButton-Up")
        button.selection:SetColorTexture(1, 0.82, 0, 0.15)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    end,

    resizeGrip = function(button)
        button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        button:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    end,
})
