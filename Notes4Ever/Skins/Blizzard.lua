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

    resizeGrip = function(button)
        button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        button:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    end,
})
