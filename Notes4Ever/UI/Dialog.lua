local addonName, ns = ...

local L, Transfer, Skin = ns.L, ns.Transfer, ns.Skin

-- The export and import dialog: one multi-line box. Export fills it and
-- selects all for Ctrl+C; import takes what is pasted and inserts it into a
-- folder. The format and its refusals are Transfer's; this is the frame.
local Dialog = {}
ns.Dialog = Dialog

local WIDTH, HEIGHT = 460, 360
-- Clears a box or line; a literal in SetText would read as a shown string.
local NO_TEXT = ""

local frame, editBox, accept, reason
-- The folder an import goes into, as { table = , id = }; nil in export mode.
local target

local function tables()
    return { account = Notes4EverDB, character = Notes4EverCharDB }
end

-- Accept that succeeds closes the dialog, so a second Accept cannot insert
-- the same notes twice; a refusal keeps it open with the reason.
local function onAccept()
    ns.Editor.Flush()
    local nodes, why = Transfer.parse(editBox:GetText())
    if nodes then
        nodes, why = Transfer.insert(tables()[target.table], target.id, nodes, time())
    end
    if not nodes then
        reason:SetText(L["IMPORT_" .. why:upper()])
        return
    end
    frame:Hide()
    ns.Tree.Expand(target.table, target.id)
    ns.Tree.Refresh()
end

-- Built on first use, parented to the notebook window so it closes with it.
local function build()
    frame = CreateFrame("Frame", nil, ns.Window.Frame(), "ButtonFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    local content = frame.Inset or frame

    accept = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    accept:SetSize(100, 22)
    accept:SetPoint("BOTTOMRIGHT", -6, 6)
    accept:SetText(ACCEPT)
    accept:SetScript("OnClick", onAccept)

    reason = content:CreateFontString(nil, "OVERLAY")
    reason:SetPoint("LEFT", content, "BOTTOMLEFT", 8, 17)
    reason:SetPoint("RIGHT", accept, "LEFT", -8, 0)
    reason:SetJustifyH("LEFT")

    local scroll = CreateFrame("Frame", nil, content, "ScrollingEditBoxTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -24, 36)
    local bar = Skin:Apply("scrollBar", CreateFrame("EventFrame", nil, content, "MinimalScrollBar"))
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    ScrollUtil.RegisterScrollBoxWithScrollBar(scroll:GetScrollBox(), bar)

    -- A new edit box takes the keyboard at once (code.md): this one only
    -- when the dialog opens, and gives it back on Escape and on hide.
    editBox = scroll:GetEditBox()
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:HookScript("OnEscapePressed", function() frame:Hide() end)
    frame:SetScript("OnHide", function() editBox:ClearFocus() end)

    Skin:Apply("dialog", frame, editBox, accept, reason)
    frame:Hide()
end

local function open(title, text, isImport)
    if not frame then build() end
    frame:SetTitle(title)
    reason:SetText(NO_TEXT)
    accept:SetShown(isImport)
    reason:SetShown(isImport)
    editBox:SetText(text)
    frame:Show()
    editBox:SetFocus()
    if not isImport then editBox:HighlightText() end
end

-- Shows an export's text, selected so Ctrl+C copies it.
function Dialog.ShowExport(text)
    target = nil
    open(L.EXPORT_TITLE, text, false)
end

-- Opens an empty box to paste an export into; Accept inserts it under the
-- folder `id` of `tableName`.
function Dialog.ShowImport(tableName, id)
    target = { table = tableName, id = id }
    open(L.IMPORT_TITLE, NO_TEXT, true)
end
