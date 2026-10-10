local addonName, ns = ...

-- Formatting a page's text where the editor shows it: the toolbar's
-- operations, and the visible text search matches. API-free; the rules are
-- plan 4a's RESEARCH, part 2, and are only summarised here.
--
-- The edit box draws WoW's own codes - colour `|cffRRGGBB` ... `|r`, icons
-- `|T...|t` - and counts its cursor in raw bytes, codes included. A typed
-- `|` is stored doubled, so `||` is always text. Format reads the text into
-- visible units, each with the colour the client shows for it, applies one
-- operation, and writes the codes back canonically: a run per colour per
-- line, never nested.
local Format = {}
ns.Format = Format

local BULLET = "\226\128\162"
local GOLD = "ffd100"

-- The palette and icons are Format's; Transfer and the toolbar read them
-- from here.
Format.PALETTE = {
    { name = "red",    rgb = "ff2020" },
    { name = "orange", rgb = "ff8000" },
    { name = "gold",   rgb = GOLD },
    { name = "green",  rgb = "20ff20" },
    { name = "blue",   rgb = "3399ff" },
    { name = "purple", rgb = "a335ee" },
    { name = "grey",   rgb = "9d9d9d" },
}

local function texture(path)
    return "|T" .. path .. ":0|t"
end

local function cutout(path, coords)
    return "|T" .. path .. ":0:0:0:0:64:64:" .. coords .. "|t"
end

local ROLES = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ICONS = {
    { name = "star",     code = texture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1") },
    { name = "circle",   code = texture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_2") },
    { name = "diamond",  code = texture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_3") },
    { name = "triangle", code = texture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_4") },
    { name = "moon",     code = texture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_5") },
    { name = "square",   code = texture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_6") },
    { name = "cross",    code = texture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_7") },
    { name = "skull",    code = texture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8") },
    { name = "quest",    code = texture("Interface\\GossipFrame\\AvailableQuestIcon") },
    { name = "turnin",   code = texture("Interface\\GossipFrame\\ActiveQuestIcon") },
    { name = "gold",     code = texture("Interface\\MoneyFrame\\UI-GoldIcon") },
    { name = "silver",   code = texture("Interface\\MoneyFrame\\UI-SilverIcon") },
    { name = "copper",   code = texture("Interface\\MoneyFrame\\UI-CopperIcon") },
    { name = "tank",     code = cutout(ROLES, "0:19:22:41") },
    { name = "healer",   code = cutout(ROLES, "20:39:1:20") },
    { name = "damage",   code = cutout(ROLES, "20:39:22:41") },
    { name = "heading",  code = texture("Interface\\Common\\Indicator-Yellow") },
    { name = "box",      code = texture("Interface\\RaidFrame\\ReadyCheck-Waiting") },
    { name = "checked",  code = texture("Interface\\RaidFrame\\ReadyCheck-Ready") },
}

local codeOf, nameOf, rgbOf = {}, {}, {}
for _, icon in ipairs(ICONS) do
    codeOf[icon.name] = icon.code
    nameOf[icon.code] = icon.name
end
for _, colour in ipairs(Format.PALETTE) do rgbOf[colour.name] = colour.rgb end

-- The Icon menu's icons: the sixteen from star to damage, not the line marks.
Format.ICON_MENU = {}
for i = 1, 16 do Format.ICON_MENU[i] = ICONS[i].name end

function Format.rgb(name)
    return rgbOf[name]
end

function Format.iconCode(name)
    return codeOf[name]
end

-- Reading -----------------------------------------------------------------

local function charLength(byte)
    if byte >= 0xF0 then return 4 end
    if byte >= 0xE0 then return 3 end
    if byte >= 0xC0 then return 2 end
    return 1
end

-- The text as units - { s = bytes, colour = rgb or nil }, { icon = name },
-- or { newline = true } - each with `last`, its last byte. Colour is a stack,
-- as the client keeps it: `|cff` pushes, `|r` pops, an `|r` on an empty
-- stack does nothing, and it carries across line ends. `codes[g]` lists the
-- codes in the gap after unit g, for reading a pending code there.
local function read(source)
    local units, codes, stack = {}, {}, {}
    local i, n = 1, #source
    local function addCode(code)
        local gap = #units
        codes[gap] = codes[gap] or {}
        codes[gap][#codes[gap] + 1] = code
    end
    while i <= n do
        local c = source:sub(i, i)
        local consumed = false
        if c == "|" then
            local nextChar = source:sub(i + 1, i + 1)
            if nextChar == "|" then
                units[#units + 1] = { s = "||", colour = stack[#stack], last = i + 1 }
                i, consumed = i + 2, true
            elseif nextChar == "r" then
                stack[#stack] = nil
                addCode({ close = true })
                i, consumed = i + 2, true
            elseif nextChar == "c" then
                local rgb = source:match("^|cff([0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])", i)
                if rgb then
                    stack[#stack + 1] = rgb
                    addCode({ rgb = rgb })
                    i, consumed = i + 10, true
                end
            elseif nextChar == "T" then
                local close = source:find("|t", i + 2, true)
                local name = close and nameOf[source:sub(i, close + 1)]
                if name then
                    units[#units + 1] = { icon = name, last = close + 1 }
                    i, consumed = close + 2, true
                end
            end
            -- A `|` that starts no code: only that byte goes.
            if not consumed then i, consumed = i + 1, true end
        elseif c == "\n" then
            units[#units + 1] = { newline = true, last = i }
            i, consumed = i + 1, true
        end
        if not consumed then
            local length = charLength(source:byte(i))
            units[#units + 1] = { s = source:sub(i, i + length - 1), colour = stack[#stack],
                                  last = i + length - 1 }
            i = i + length
        end
    end
    return units, codes
end

-- Line ranges: units s..e, the newline after e not included.
local function linesOf(units)
    local lines, s = {}, 1
    for k, unit in ipairs(units) do
        if unit.newline then
            lines[#lines + 1] = { s = s, e = k - 1 }
            s = k + 1
        end
    end
    lines[#lines + 1] = { s = s, e = #units }
    return lines
end

-- The line a gap belongs to: gap s - 1, before its first unit, to gap e.
local function lineIndexOf(lines, gap)
    for index, line in ipairs(lines) do
        if gap >= line.s - 1 and gap <= line.e then return index end
    end
    return #lines
end

local function kindOf(units, line)
    local first, second = units[line.s], units[line.s + 1]
    if line.s + 1 > line.e or not second or second.s ~= " " then return nil end
    if first.icon == "heading" then return "heading" end
    if first.icon == "box" or first.icon == "checked" then return "checkbox" end
    if first.s == BULLET then return "bullet" end
end

-- The colour of the run open across a gap: the nearest non-icon units on
-- its line, on both sides, carrying the same colour; nil if none.
local function runAt(units, line, gap)
    local before, after
    for k = gap, line.s, -1 do
        if not units[k].icon then before = units[k]; break end
    end
    for k = gap + 1, line.e do
        if not units[k].icon then after = units[k]; break end
    end
    if before and after and before.colour and before.colour == after.colour then
        return before.colour
    end
end

-- The state an operation works on: units, the cursor's gap, and the pending
-- code there, if any. A byte inside a unit counts as the gap before it.
function Format.state(source, cursor)
    local units, codes = read(source)
    local gap = 0
    for k, unit in ipairs(units) do
        if unit.last <= cursor then gap = k end
    end
    local state = { units = units, gap = gap }

    local lines = linesOf(units)
    local line = lines[lineIndexOf(lines, gap)]
    if kindOf(units, line) ~= "heading" then
        local found = codes[gap] or {}
        for k = 1, #found - 1 do
            if found[k].rgb and found[k + 1].close then state.pending = { colour = found[k].rgb } end
        end
        if not state.pending then
            local run = runAt(units, line, gap)
            for k = 1, #found - 1 do
                if run and found[k].close and found[k + 1].rgb == run then
                    state.pending = { default = true }
                end
            end
        end
    end
    return state
end

-- Writing -----------------------------------------------------------------

local function bytesOf(unit)
    if unit.icon then return codeOf[unit.icon] end
    if unit.newline then return "\n" end
    return unit.s
end

-- Writes the state back canonically and returns the text and cursor.
-- `mode` places the cursor in its gap: after the unit before it (default),
-- after any colour end there ("afterClose"), or after any colour start.
local function write(state, mode)
    local units, cursorGap, pending = state.units, state.gap, state.pending
    local out, length, cursor = {}, 0, nil
    local function put(s)
        out[#out + 1] = s
        length = length + #s
    end

    -- Handles gap k: closes, a pending code, opens. Returns the open colour.
    local function gap(k, open, nextColour)
        local atCursor = k == cursorGap
        local afterUnit = length
        if atCursor and pending then
            if pending.colour then
                if open and nextColour == open then
                    put("|r"); put("|cff" .. pending.colour); cursor = length
                    put("|r"); put("|cff" .. open)
                    return open
                end
                if open then put("|r") end
                put("|cff" .. pending.colour); cursor = length; put("|r")
                if nextColour then put("|cff" .. nextColour) end
                return nextColour
            elseif open and nextColour == open then
                put("|r"); cursor = length; put("|cff" .. open)
                return open
            end
        end
        if open and nextColour ~= open then put("|r") end
        local afterClose = length
        if nextColour and nextColour ~= open then put("|cff" .. nextColour) end
        if atCursor then
            if mode == "afterClose" then cursor = afterClose
            elseif mode == "afterOpen" then cursor = length
            else cursor = afterUnit end
        end
        return nextColour
    end

    local lines = linesOf(units)
    for index, line in ipairs(lines) do
        local kind = kindOf(units, line)
        if kind == "heading" then
            if cursorGap == line.s - 1 then cursor = length end
            put(bytesOf(units[line.s]))
            if cursorGap == line.s then cursor = length end
            put(" ")
            put("|cff" .. GOLD)
            -- Right after the prefix, typing is gold.
            if cursorGap == line.s + 1 then cursor = length end
            for k = line.s + 2, line.e do
                put(bytesOf(units[k]))
                if cursorGap == k then cursor = length end
            end
            put("|r")
        else
            local open
            local first = line.s
            if kind then
                -- A prefix is written Default.
                gap(line.s - 1, nil, nil)
                put(bytesOf(units[line.s]))
                gap(line.s, nil, nil)
                put(bytesOf(units[line.s + 1]))
                first = line.s + 2
            end
            for k = first, line.e do
                local unit, nextColour = units[k], nil
                if unit.icon then
                    -- An icon stays inside a run that continues past it on
                    -- its line, and outside one that does not.
                    for j = k + 1, line.e do
                        if not units[j].icon then
                            if open and units[j].colour == open then nextColour = open end
                            break
                        end
                    end
                else
                    nextColour = unit.colour
                end
                open = gap(k - 1, open, nextColour)
                put(bytesOf(unit))
            end
            gap(line.e, open, nil)
        end
        if index < #lines then put("\n") end
    end
    return table.concat(out), cursor or length
end

-- Operations ----------------------------------------------------------------

local function currentLine(state)
    local lines = linesOf(state.units)
    local index = lineIndexOf(lines, state.gap)
    return lines[index], index
end

local function isWordUnit(units, line, kind, k)
    local first = kind and line.s + 2 or line.s
    if k < first or k > line.e then return false end
    local s = units[k].s
    return s ~= " " and s ~= "\t"
end

function Format.colour(source, cursor, rgb)
    local state = Format.state(source, cursor)
    local units, gap = state.units, state.gap
    local line = currentLine(state)
    local kind = kindOf(units, line)
    if kind == "heading" or (kind and gap == line.s) then return write(state) end

    local run = runAt(units, line, gap)
    local pending = state.pending
    local mode
    if pending and pending.colour then
        if rgb == nil then
            state.pending = run and { default = true } or nil
        elseif rgb == run then
            state.pending = nil
        else
            state.pending = { colour = rgb }
        end
    elseif pending and pending.default then
        if rgb == run then
            state.pending = nil
        elseif rgb then
            state.pending = { colour = rgb }
        end
    else
        local wordStart, wordEnd
        if isWordUnit(units, line, kind, gap) then
            wordEnd = gap
        elseif isWordUnit(units, line, kind, gap + 1) then
            wordStart = gap + 1
        end
        if wordStart or wordEnd then
            wordStart = wordStart or wordEnd
            wordEnd = wordEnd or wordStart
            while isWordUnit(units, line, kind, wordStart - 1) do wordStart = wordStart - 1 end
            while isWordUnit(units, line, kind, wordEnd + 1) do wordEnd = wordEnd + 1 end
            for k = wordStart, wordEnd do
                if not units[k].icon then units[k].colour = rgb end
            end
            -- At the word's edge the cursor stands outside its colour codes,
            -- where the word has its own and they are in the cursor's gap.
            if rgb and ((gap == wordStart - 1 and not units[wordStart].icon)
                     or (gap == wordEnd and not units[wordEnd].icon)) then
                mode = "afterClose"
            end
        elseif rgb then
            if run ~= rgb then state.pending = { colour = rgb } end
        elseif run then
            state.pending = { default = true }
        end
    end
    return write(state, mode)
end

-- Removes the current line's prefix: a cursor inside it goes to the start
-- of what remains. A heading's gold goes with it.
local function removePrefix(state, line, kind)
    table.remove(state.units, line.s)
    table.remove(state.units, line.s)
    if state.gap >= line.s + 1 then
        state.gap = state.gap - 2
    elseif state.gap == line.s then
        state.gap = line.s - 1
    end
    if state.gap < line.s - 1 then state.gap = line.s - 1 end
    if kind == "heading" then
        for k = line.s, line.e - 2 do state.units[k].colour = nil end
    end
end

-- Puts a prefix first: a cursor at the line's start goes after it.
local function addPrefix(state, line, first)
    table.insert(state.units, line.s, { s = " " })
    table.insert(state.units, line.s, first)
    if state.gap >= line.s then
        state.gap = state.gap + 2
    elseif state.gap == line.s - 1 then
        state.gap = line.s + 1
    end
end

local function lineOperation(source, cursor, target)
    local state = Format.state(source, cursor)
    local line, index = currentLine(state)
    local kind = kindOf(state.units, line)

    if target == "checkbox" and kind == "checkbox" then
        local box = state.units[line.s]
        box.icon = box.icon == "box" and "checked" or "box"
        return write(state)
    end
    if kind then
        removePrefix(state, line, kind)
        if kind == target then return write(state) end
        line = linesOf(state.units)[index]
    end

    if target == "heading" then
        addPrefix(state, line, { icon = "heading" })
        state.pending = nil
        line = linesOf(state.units)[index]
        for k = line.s + 2, line.e do
            if not state.units[k].icon then state.units[k].colour = GOLD end
        end
    elseif target == "bullet" then
        addPrefix(state, line, { s = BULLET })
    else
        addPrefix(state, line, { icon = "box" })
    end
    return write(state)
end

function Format.heading(source, cursor)
    return lineOperation(source, cursor, "heading")
end

function Format.bullet(source, cursor)
    return lineOperation(source, cursor, "bullet")
end

function Format.checkbox(source, cursor)
    return lineOperation(source, cursor, "checkbox")
end

-- Inserts an icon at the cursor; a pending code there moves past it.
function Format.icon(source, cursor, name)
    local state = Format.state(source, cursor)
    table.insert(state.units, state.gap + 1, { icon = name })
    state.gap = state.gap + 1
    return write(state)
end

-- The visible text: codes and icons gone, a lone `|` dropped, `||` kept -
-- the search box doubles a typed `|` too.
function Format.plain(source)
    local units = read(source)
    local out = {}
    for _, unit in ipairs(units) do
        if unit.newline then
            out[#out + 1] = "\n"
        elseif not unit.icon then
            out[#out + 1] = unit.s
        end
    end
    return table.concat(out)
end
