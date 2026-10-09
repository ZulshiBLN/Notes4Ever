-- The source check for code.md's skin and string rules. It must report each
-- kind of violation in a fixture - a check that finds nothing in an empty
-- folder proves nothing - and then find the real addon clean.

local sourcecheck = require("sourcecheck")
local lfs = require("lfs")

local function rulesIn(source, path)
    local rules = {}
    for _, f in ipairs(sourcecheck.check(source, path or "Notes4Ever/UI/Fixture.lua")) do
        rules[#rules + 1] = f.rule
    end
    return rules
end

describe("source check", function()
    it("reports styling outside Skins/", function()
        for _, line in ipairs({
            'frame:SetBackdrop(backdrop)',
            'tex:SetTexture(path)',
            'tex:SetAtlas("UI-Frame")',
            'label:SetTextColor(1, 0, 0)',
            'edit:SetFontObject(GameFontNormal)',
        }) do
            assert.are.same({ "styling" }, rulesIn(line .. "\n"), line)
        end
    end)

    it("lets Skins/ style", function()
        assert.are.same({}, rulesIn("frame:SetBackdrop(backdrop)\n", "Notes4Ever/Skins/Blizzard.lua"))
    end)

    it("reports a literal shown directly", function()
        for _, line in ipairs({
            'label:SetText("Notes")',
            "frame:SetTitle('Notes4Ever')",
            'print("loaded")',
            'StaticPopupDialogs.NOTES4EVER_DELETE = { text = "Delete?" }',
            'label:SetText([[Notes]])',
        }) do
            assert.are.same({ "literal" }, rulesIn(line .. "\n"), line)
        end
    end)

    it("lets strings come from L, and lets Locales/ hold literals", function()
        assert.are.same({}, rulesIn('label:SetText(L.TITLE)\nprint(L.USAGE:format(addonName))\n'))
        assert.are.same({}, rulesIn('ns.L_enUS = { TITLE = "Notes" }\n', "Notes4Ever/Locales/enUS.lua"))
    end)

    it("does not take a text field assignment for a popup text", function()
        assert.are.same({}, rulesIn('node.text = ""\n'))
    end)

    -- project.md: a UI suite is reached only through its public API, behind
    -- ns.Skin - so only its adapter names it.
    it("reports EllesmereUI named outside its adapter", function()
        for _, line in ipairs({
            'if EllesmereUI then end',
            'local S = EllesmereUI.RegisterSkin',
            'local db = EllesmereUIDB',
        }) do
            assert.are.same({ "suite" }, rulesIn(line .. "\n"), line)
        end
    end)

    it("lets the adapter name EllesmereUI, and ignores it in strings and comments", function()
        assert.are.same({}, rulesIn("if EllesmereUI then end\n", "Notes4Ever/Skins/EllesmereUI.lua"))
        assert.are.same({}, rulesIn('local name = "EllesmereUI"\n'))
        assert.are.same({}, rulesIn("local name = 'EllesmereUI'\n"))
        assert.are.same({}, rulesIn("-- EllesmereUI calls back at login\n"))
        assert.are.same({ "suite" }, rulesIn("if EllesmereUI then end\n", "Notes4Ever/Skins/Blizzard.lua"))
    end)

    it("ignores what only a comment says", function()
        assert.are.same({}, rulesIn('-- frame:SetBackdrop(x) and print("x") are not done here\n'))
    end)

    it("finds the addon itself clean", function()
        local checked = 0
        local function walk(dir)
            for entry in lfs.dir(dir) do
                if entry ~= "." and entry ~= ".." then
                    local path = dir .. "/" .. entry
                    if lfs.attributes(path, "mode") == "directory" then
                        walk(path)
                    elseif entry:match("%.lua$") then
                        local f = assert(io.open(path, "rb"))
                        local findings = sourcecheck.check(f:read("*a"), path)
                        f:close()
                        checked = checked + 1
                        assert.are.same({}, findings, path)
                    end
                end
            end
        end
        walk("Notes4Ever")
        assert.is_true(checked > 0)
    end)
end)
