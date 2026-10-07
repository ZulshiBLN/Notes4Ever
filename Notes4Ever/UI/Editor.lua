local addonName, ns = ...

local L, View, Skin = ns.L, ns.View, ns.Skin

-- The page editor on the window's right. What is open and what is not yet
-- written lives in View's editor state; this file is the frame, the pause
-- timer, and the calls into that state.
local Editor = {}
ns.Editor = Editor

-- Typed text is written after this many seconds without a keystroke, and
-- at once on every other flush trigger.
local SAVE_DELAY = 1.5

local state = View.newEditor()
local frame, editBox, hint, timer
-- True while the editor fills itself, so that does not count as typing.
local filling = false

local function tables()
    return { account = Notes4EverDB, character = Notes4EverCharDB }
end

-- Shows the open page, or the hint when no page is open.
local function showState(text)
    local open = View.editorPage(state) ~= nil
    if open then
        filling = true
        editBox:SetText(text or "")
        filling = false
    else
        editBox:ClearFocus()
    end
    frame:SetShown(open)
    hint:SetShown(not open)
end

-- Writes what is pending. Safe to call at any time; does nothing if there
-- is nothing to write, and closes the editor if its page has gone.
function Editor.Flush()
    if timer then
        timer:Cancel()
        timer = nil
    end
    View.editorFlush(state, tables(), time())
    if frame and not View.editorPage(state) then showState() end
end

function Editor.Open(tableName, id)
    local text = View.editorOpen(state, tables(), tableName, id, time())
    if frame then showState(text) end
end

-- After a move across tables the open page may have a new id.
function Editor.Follow(fromTable, toTable, ids)
    View.editorFollow(state, fromTable, toTable, ids)
end

local function onTextChanged(box)
    if filling then return end
    View.editorType(state, box:GetText())
    if timer then timer:Cancel() end
    timer = C_Timer.NewTimer(SAVE_DELAY, Editor.Flush)
end

function Editor.Create(parent, left)
    frame = CreateFrame("Frame", nil, parent, "ScrollingEditBoxTemplate")
    frame:SetPoint("TOPLEFT", left, -6)
    frame:SetPoint("BOTTOMRIGHT", -6, 6)
    editBox = frame:GetEditBox()

    -- A new edit box takes the keyboard at once (code.md); this one only
    -- when clicked, and gives it back on Escape.
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:HookScript("OnTextChanged", onTextChanged)
    editBox:HookScript("OnEscapePressed", editBox.ClearFocus)
    Skin:Apply("editor", frame, editBox)

    hint = parent:CreateFontString(nil, "OVERLAY")
    hint:SetPoint("CENTER", frame, "CENTER")
    Skin:Apply("hint", hint)
    hint:SetText(L.EDITOR_HINT)

    showState()
end
