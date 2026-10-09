local addonName, ns = ...

-- Notes as text and back: the export a player copies out of the game as a
-- backup or to share, and the import that reads it in. API-free like the
-- model, so busted runs every rule here. The format, version 1, is
-- specified in plan 3's RESEARCH companion; the comments say why, not how.
--
-- `|` is not touched here: the client's edit boxes store a typed or pasted
-- `|` doubled, and undo that when the text is copied out of them.
local Model = ns.Model
local Transfer = {}
ns.Transfer = Transfer

local HEADER = "Notes4Ever export 1"
local VERSION = 1

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

local function writeNode(out, node, depth)
    local isFolder = node.kind == "folder"
    out[#out + 1] = string.rep("#", depth) .. " " .. encodeTitle(node.title, isFolder)
    if isFolder then
        for _, child in ipairs(node.children) do writeNode(out, child, depth + 1) end
    elseif node.text ~= "" then
        -- n newlines are n + 1 lines; a line that would read as a node line
        -- or as an escape gets one leading backslash.
        for line in (node.text .. "\n"):gmatch("([^\n]*)\n") do
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

local function readHeader(line)
    local version = tonumber(trimEnd(line or ""):match("^Notes4Ever export (%d+)$"))
    if not version or version < VERSION then return "bad_header" end
    if version > VERSION then return "newer_version" end
end

-- Reads an export into plain nodes - kind, title, then text or children -
-- or returns nil and the reason, stopping at the first offending line.
function Transfer.parse(text)
    local lines = splitLines(text)
    local headerError = readHeader(lines[1])
    if headerError then return nil, headerError end

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
