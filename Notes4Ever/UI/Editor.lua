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
local frame, editBox, hint, toolbar, timer
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
    toolbar:SetShown(open)
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

-- The toolbar's one way in: `op(text, cursor)` returns the new text and
-- cursor. The result is set as the editor's own fill, written at once, and
-- the box gets the keyboard back - a click on a button or menu took it.
-- The cursor survives that click (probe 11), so it is read here.
function Editor.Apply(op)
    if not View.editorPage(state) then return end
    local text, cursor = op(editBox:GetText(), editBox:GetCursorPosition())
    filling = true
    editBox:SetText(text)
    filling = false
    View.editorType(state, text)
    Editor.Flush()
    editBox:SetFocus()
    editBox:SetCursorPosition(cursor)
end

function Editor.Create(parent, left)
    -- Reached at call time: the TOC loads Toolbar after this file.
    toolbar = ns.Toolbar.Create(parent)
    toolbar:SetPoint("TOPLEFT", left, -6)
    toolbar:SetPoint("RIGHT", -6, 0)

    frame = CreateFrame("Frame", nil, parent, "ScrollingEditBoxTemplate")
    frame:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
    frame:SetPoint("BOTTOMRIGHT", -6, 6)
    editBox = frame:GetEditBox()

    -- A new edit box takes the keyboard at once (code.md); this one only
    -- when clicked, and gives it back on Escape.
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:HookScript("OnTextChanged", onTextChanged)
    editBox:HookScript("OnEscapePressed", editBox.ClearFocus)
    Skin:Apply("editor", frame, editBox)

    -- Held between the editor's sides so it wraps: anchored by its centre
    -- alone it ran past the window at the minimum size.
    hint = parent:CreateFontString(nil, "OVERLAY")
    hint:SetPoint("LEFT", frame, "LEFT", 12, 0)
    hint:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    hint:SetJustifyH("CENTER")
    Skin:Apply("hint", hint)
    hint:SetText(L.EDITOR_HINT)

    showState()
end
