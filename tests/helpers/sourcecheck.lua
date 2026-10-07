-- Two rules from the ruleset's code.md, read off the source: every frame is
-- styled through ns.Skin (so only Skins/ may call styling methods), and
-- every visible string comes from L (so no literal is shown directly).
-- Pattern-based: it catches the direct forms, not a string built elsewhere
-- and passed in through a variable.
local M = {}

local STYLING = {
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetTexture", "SetAtlas", "SetColorTexture", "SetVertexColor",
    "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetDisabledTexture",
    "SetFont", "SetFontObject", "SetTextColor",
}

-- A string literal starts with " or ' or [[ / [=[.
local LITERAL = "[\"'%[]"
-- A popup's text is a `text =` field in a table constructor - after `{`, `,`
-- or at the start of a line - not an assignment like `node.text = ""`.
local SHOWN = {
    ":SetText%s*%(%s*" .. LITERAL,
    ":SetTitle%s*%(%s*" .. LITERAL,
    "%f[%w_]print%s*%(%s*" .. LITERAL,
    "[{,]%s*text%s*=%s*" .. LITERAL,
    "^%s*text%s*=%s*" .. LITERAL,
}

-- Line comments are dropped first; a "--" inside a string is rare here and
-- would only hide a finding, never invent one.
local function code(line)
    return (line:gsub("%-%-.*$", ""))
end

-- Returns the findings for one file: { rule = "styling" | "literal", line = n }.
function M.check(source, path)
    local findings = {}
    local styled = path:find("Skins/", 1, true) or path:find("Skins\\", 1, true)
    local locale = path:find("Locales/", 1, true) or path:find("Locales\\", 1, true)
    local n = 0
    for line in (source .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        local text = code(line)
        if not styled then
            for _, method in ipairs(STYLING) do
                if text:find(":" .. method .. "%s*%(") then
                    findings[#findings + 1] = { rule = "styling", line = n, what = method }
                end
            end
        end
        if not locale then
            for _, pattern in ipairs(SHOWN) do
                if text:find(pattern) then
                    findings[#findings + 1] = { rule = "literal", line = n, what = pattern }
                end
            end
        end
    end
    return findings
end

return M
