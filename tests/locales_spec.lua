-- Locale files run as the client runs them, with GetLocale answering for the
-- client. Keys are read from enUS.lua, the authority, never retyped here.

local addon = require("addon")

-- Loads enUS and then deDE, as the TOC orders them, and returns the
-- namespace. A changed deDE source can be passed in.
local function load(clientLocale, deDESource)
    local ns = {}
    local env = { GetLocale = function() return clientLocale end }
    addon.load("Notes4Ever/Locales/enUS.lua", ns, env)
    addon.run(deDESource or addon.read("Notes4Ever/Locales/deDE.lua"), "deDE", ns, env)
    return ns
end

local function placeholders(s)
    local count = 0
    for _ in s:gmatch("%%s") do count = count + 1 end
    return count
end

describe("locales", function()
    it("every enUS key has its own German entry", function()
        local ns = load("deDE")
        for key, english in pairs(ns.L_enUS) do
            local german = rawget(ns.L, key)
            assert.is_string(german, key)
            assert.are_not.equal(english, german, key)
        end
    end)

    it("keeps each string's placeholders, so format() cannot fail", function()
        local ns = load("deDE")
        for key, english in pairs(ns.L_enUS) do
            assert.are.equal(placeholders(english), placeholders(ns.L[key]), key)
        end
    end)

    it("falls back to English for a key German lacks", function()
        local source = addon.read("Notes4Ever/Locales/deDE.lua")
        local key = next(load("enUS").L_enUS)
        local withoutKey, removed = source:gsub("\n%s*" .. key .. "%s*=[^\n]*", "")
        assert.are.equal(1, removed, "test copy should lose exactly " .. key)

        local ns = load("deDE", withoutKey)
        assert.is_nil(rawget(ns.L, key))
        assert.are.equal(ns.L_enUS[key], ns.L[key])
    end)

    it("leaves English untouched on any other client", function()
        local ns = load("enUS")
        assert.are.equal(ns.L_enUS, ns.L)
    end)
end)
