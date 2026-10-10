local addonName, ns = ...

-- Notes as text and back: the export a player copies out of the game as a
-- backup or to share, and the import that reads it in. API-free like the
-- model, so busted runs every rule here. Version 1 is specified in plan 3's
-- RESEARCH companion, version 2 in plan 4a's; the comments say why, not how.
--
-- Version 2 writes Notes4Ever's codes in page text as readable tokens -
-- `{red}`, `{/}`, `{icon:skull}` - so an export stays readable outside the
-- game. A typed `|` is stored doubled; the client's edit boxes undo that
-- when the text is copied out of them, so `||` is written as it is.
local Model, Format = ns.Model, ns.Format
local Transfer = {}
ns.Transfer = Transfer

local HEADER = "Notes4Ever export 2"
local OLDEST = 1
local VERSION = 2

local function trimEnd(s)
    return (s:gsub("[ \t]+$", ""))
end

-- Trailing whitespace goes first: parse trims node lines, so a page `a/ `
-- written as `# a/ ` would come back as a folder.
local function encodeTitle(title, isFolder)
    local encoded = trimEnd(title:gsub("\n", " ")):gsub("\\", "\\\\")
    if isFolder then return encoded .. "/" end
    return (encoded:gsub("/$", "\\/"))
end

-- A stored line with its codes as tokens, `\` and `{` escaped so they read
-- back as text. A lone `|` is written `||`: it reads back as a typed `|`.
local function encodeLine(line)
    local out, i = {}, 1
    while i <= #line do
        local c = line:sub(i, i)
        if c == "|" then
            local kind, value, length = Format.codeAt(line, i)
            if kind == "colour" then
                out[#out + 1] = "{" .. (Format.colourName(value) or "#" .. value) .. "}"
            elseif kind == "close" then
                out[#out + 1] = "{/}"
            elseif kind == "icon" then
                out[#out + 1] = "{icon:" .. value .. "}"
            else
                out[#out + 1] = "||"
            end
            i = i + length
        else
            out[#out + 1] = (c == "\\" or c == "{") and "\\" .. c or c
            i = i + 1
        end
    end
    return table.concat(out)
end

local function writeNode(out, node, depth)
    local isFolder = node.kind == "folder"
    out[#out + 1] = string.rep("#", depth) .. " " .. encodeTitle(node.title, isFolder)
    if isFolder then
        for _, child in ipairs(node.children) do writeNode(out, child, depth + 1) end
    elseif node.text ~= "" then
        -- n newlines are n + 1 lines; a written line that would read as a
        -- node line or as an escape gets one leading backslash.
        for line in (node.text .. "\n"):gmatch("([^\n]*)\n") do
            line = encodeLine(line)
            if line:find("^[#\\]") then line = "\\" .. line end
            out[#out + 1] = line
        end
    end
end

-- The node `id` of `db` as text: a root as its children, any other node as
-- itself. The caller flushes the editor first.
function Transfer.export(db, id)
    local node, parent = Model.find(db, id)
    if not node then return nil, "not_found" end
    local out = { HEADER }
    if parent then
        writeNode(out, node, 1)
    else
        for _, child in ipairs(node.children) do writeNode(out, child, 1) end
    end
    return table.concat(out, "\n") .. "\n"
end

-- Decodes left to right, so `\\/` is a backslash and a folder's slash while
-- `\/` is a page's slash. Returns the title and whether it names a folder.
local function decodeTitle(encoded)
    local chars, escaped = {}, {}
    local i = 1
    while i <= #encoded do
        local c, nextChar = encoded:sub(i, i), encoded:sub(i + 1, i + 1)
        if c == "\\" and (nextChar == "\\" or nextChar == "/") then
            chars[#chars + 1], escaped[#chars + 1] = nextChar, true
            i = i + 2
        else
            chars[#chars + 1], escaped[#chars + 1] = c, false
            i = i + 1
        end
    end
    local isFolder = chars[#chars] == "/" and not escaped[#chars]
    if isFolder then chars[#chars] = nil end
    return table.concat(chars), isFolder
end

local function splitLines(text)
    text = text:gsub("\r\n", "\n")
    if text:sub(-1) ~= "\n" then text = text .. "\n" end
    local lines = {}
    for line in text:gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
    return lines
end

-- Returns the version, or nil and the reason.
local function readHeader(line)
    local version = tonumber(trimEnd(line or ""):match("^Notes4Ever export (%d+)$"))
    if not version or version < OLDEST then return nil, "bad_header" end
    if version > VERSION then return nil, "newer_version" end
    return version
end

-- A token's code: a palette name, `#rrggbb` in either case, `/`, or
-- `icon:` and a name; nil for anything else.
local function tokenCode(token)
    local rgb = Format.rgb(token)
    if not rgb and token:find("^#%x%x%x%x%x%x$") then rgb = token:sub(2):lower() end
    if rgb then return "|cff" .. rgb end
    if token == "/" then return "|r" end
    local name = token:match("^icon:(.*)$")
    return name and Format.iconCode(name)
end

-- A version 2 text line, its leading escape already dropped, back to the
-- stored text; nil for an unknown token or a `{` without its `}`.
local function decodeLine(line)
    local out, i = {}, 1
    while i <= #line do
        local c, nextChar = line:sub(i, i), line:sub(i + 1, i + 1)
        if c == "\\" and (nextChar == "\\" or nextChar == "{") then
            out[#out + 1] = nextChar
            i = i + 2
        elseif c == "{" then
            local close = line:find("}", i + 1, true)
            local code = close and tokenCode(line:sub(i + 1, close - 1))
            if not code then return nil end
            out[#out + 1] = code
            i = close + 1
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out)
end

-- Reads an export into plain nodes - kind, title, then text or children -
-- or returns nil and the reason, stopping at the first offending line.
function Transfer.parse(text)
    local lines = splitLines(text)
    local version, headerError = readHeader(lines[1])
    if not version then return nil, headerError end

    local top = {}
    -- stack[d] is the last node at depth d; depth 0 stands for `top`.
    local stack = { [0] = { kind = "folder", children = top } }
    local depth, pageLines = 0, nil

    local function closePage()
        if pageLines then stack[depth].text = table.concat(pageLines, "\n") end
        pageLines = nil
    end

    for n = 2, #lines do
        local line = lines[n]
        if line:sub(1, 1) == "#" then
            local hashes, encoded = trimEnd(line):match("^(#+) (.*)$")
            if not hashes then return nil, "bad_node_line" end
            local nodeDepth = #hashes
            if nodeDepth > depth + 1 then return nil, "depth_jump" end
            local parent = stack[nodeDepth - 1]
            if parent.kind ~= "folder" then return nil, "child_of_page" end
            local title, isFolder = decodeTitle(encoded)
            if not title:find("%S") then return nil, "blank_title" end

            closePage()
            local node = { kind = isFolder and "folder" or "page", title = title }
            if isFolder then node.children = {} else pageLines = {} end
            parent.children[#parent.children + 1] = node
            stack[nodeDepth], depth = node, nodeDepth
        elseif pageLines then
            if line:sub(1, 1) == "\\" then line = line:sub(2) end
            if version >= 2 then
                line = decodeLine(line)
                if not line then return nil, "bad_markup" end
            end
            pageLines[#pageLines + 1] = line
        elseif not line:find("^%s*$") then
            return nil, "text_outside_page"
        end
    end
    closePage()

    if #top == 0 then return nil, "empty" end
    return top
end

-- Appends parsed nodes under a folder of `db`, with fresh ids and times;
-- nil and a reason, changing nothing, if the folder is gone or a page.
function Transfer.insert(db, folderId, nodes, now)
    return Model.attach(db, folderId, nodes, now)
end
