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
        button.icon:SetTexture(row.kind == "folder"
            and "Interface\\Icons\\INV_Misc_Bag_07"
            or "Interface\\Icons\\INV_Misc_Note_01")
        -- Item icons carry a border; trimming it keeps them crisp at 14px.
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.selection:SetColorTexture(1, 0.82, 0, 0.15)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    end,

    editor = function(_, editBox)
        editBox:SetFontObject(GameFontHighlight)
    end,

    hint = function(fontString)
        fontString:SetFontObject(GameFontDisable)
    end,

    -- The search box: SearchBoxTemplate brings the game's art, magnifier and
    -- font, so the base adds nothing; the role exists for an overlay.
    searchBox = function() end,

    -- The export and import dialog: a ButtonFrameTemplate like the window.
    -- The fonts are set here so an overlay re-fonting them finds an object.
    dialog = function(frame, editBox, _, reason)
        if ButtonFrameTemplate_HidePortrait then
            ButtonFrameTemplate_HidePortrait(frame)
        end
        editBox:SetFontObject(GameFontHighlight)
        reason:SetFontObject(GameFontRed)
    end,

    -- The toolbar's buttons: UIPanelButtonTemplate brings the game's art, so
    -- the base adds nothing; the role exists for an overlay.
    toolbarButton = function() end,

    resizeGrip = function(button)
        button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        button:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    end,
})
