-- The globals rule is only enforced if .luacheckrc is actually strict. This
-- runs the real luacheck with the real config against snippets that must be
-- refused, so a config loosened by accident turns this red.

local luacheck = require("luacheck")
local lfs = require("lfs")

-- The config is Lua that assigns globals; run it in an empty environment and
-- hand what it set to luacheck as options. The per-path `files` section is
-- returned apart: a snippet stands in for ordinary addon code unless a test
-- names the path it stands for.
local function loadConfig()
    local options = { files = {} }
    local chunk = assert(loadfile(".luacheckrc"))
    setfenv(chunk, options)
    chunk()
    local files = options.files
    options.files = nil
    return options, files
end

-- Options for sources at `paths`: the config, plus each path's own section
-- in the array part, which luacheck applies per source.
local function configFor(paths)
    local options, files = loadConfig()
    for i, path in ipairs(paths) do options[i] = files[path] or {} end
    return options
end

local function warningsFor(source)
    local report = luacheck.check_strings({ source }, loadConfig())
    return report.warnings + report.errors
end

-- Any warning is not enough: a loosened config can trade the refusal for a
-- different, weaker warning (allow_defined_top turns "setting an undefined
-- global" into "unused global"). Each case asks for the refusal's own code.
local function hasCode(source, code)
    local report = luacheck.check_strings({ source }, loadConfig())
    for _, w in ipairs(report[1]) do
        if w.code == code then return true end
    end
    return false
end

describe(".luacheckrc", function()
    it("refuses writing a global the rule does not allow", function()
        assert.is_true(hasCode("Notes4EverScratch = 1\n", "111"))
    end)

    it("refuses io, os, require, dofile and loadfile", function()
        for _, name in ipairs({ "io", "os", "require", "dofile", "loadfile" }) do
            assert.is_true(hasCode("local x = " .. name .. "\nreturn x\n", "113"), name)
        end
    end)

    it("refuses defining a top-level function", function()
        assert.is_true(hasCode("function Notes4EverHelper() end\n", "111"))
    end)

    it("refuses writing another addon's slash command entry", function()
        assert.is_true(hasCode("SlashCmdList.SOMEONE_ELSE = print\n", "142"))
    end)

    it("refuses writing another addon's popup entry", function()
        assert.is_true(hasCode("StaticPopupDialogs.SOMEONE_ELSE = {}\n", "142"))
    end)

    it("allows exactly the globals the rule names", function()
        local allowed = table.concat({
            "Notes4EverDB = {}",
            "Notes4EverCharDB = {}",
            'SLASH_NOTES4EVER1 = "/n4e"',
            "SlashCmdList.NOTES4EVER = print",
            "StaticPopupDialogs.NOTES4EVER_DELETE = {}",
            "StaticPopupDialogs.NOTES4EVER_NAME = {}",
            "function Notes4Ever_OnAddonCompartmentClick() end",
        }, "\n") .. "\n"
        assert.are.equal(0, warningsFor(allowed))
    end)

    it("finds the addon's own files clean", function()
        local sources, names = {}, {}
        local function walk(dir)
            for entry in lfs.dir(dir) do
                if entry ~= "." and entry ~= ".." then
                    local path = dir .. "/" .. entry
                    if lfs.attributes(path, "mode") == "directory" then
                        walk(path)
                    elseif entry:match("%.lua$") then
                        local f = assert(io.open(path, "rb"))
                        sources[#sources + 1] = f:read("*a")
                        names[#names + 1] = path
                        f:close()
                    end
                end
            end
        end
        walk("Notes4Ever")
        assert.is_true(#sources > 0)
        local report = luacheck.check_strings(sources, configFor(names))
        assert.are.equal(0, report.warnings + report.errors, table.concat(names, ", "))
    end)

    -- project.md: a UI suite is reached only through its adapter.
    it("knows EllesmereUI in its adapter alone", function()
        local source = "local S = EllesmereUI\nreturn S\n"
        local report = luacheck.check_strings({ source, source, source }, configFor({
            "Notes4Ever/Skins/EllesmereUI.lua", "Notes4Ever/Skins/Blizzard.lua", "Notes4Ever/Core.lua",
        }))
        assert.are.equal(0, #report[1])
        for i = 2, 3 do
            assert.are.equal("113", report[i][1] and report[i][1].code, i)
        end
    end)
end)
