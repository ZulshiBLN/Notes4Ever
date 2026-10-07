-- The globals rule from the ruleset's code.md, made checkable: the addon may
-- write only what the client or another addon must find by name.
std = "lua51"
max_line_length = false

-- WoW's Lua has no file, process or module loading. lua51 would allow them.
not_globals = { "io", "os", "require", "dofile", "loadfile", "module" }

globals = {
    "Notes4EverDB",
    "Notes4EverCharDB",
    "SLASH_NOTES4EVER1",
    "SLASH_NOTES4EVER2",
    "Notes4Ever_OnAddonCompartmentClick",
}

-- The WoW API the addon reads, listed by hand so a typo or a removed API is
-- reported instead of trusted. SlashCmdList and StaticPopupDialogs are shared
-- by every addon; only our own entries may be written.
read_globals = {
    "ACCEPT",
    "CANCEL",
    "MenuUtil",
    "NO",
    "StaticPopup_Show",
    "YES",
    "ButtonFrameTemplate_HidePortrait",
    "C_AddOns",
    "C_Timer",
    "GameFontDisable",
    "GameFontHighlight",
    "CreateDataProvider",
    "CreateFrame",
    "CreateScrollBoxListLinearView",
    "GameFontHighlightSmall",
    "GameFontNormal",
    "GetLocale",
    "ScrollBoxConstants",
    "ScrollUtil",
    "UIParent",
    "UISpecialFrames",
    "UnitGUID",
    "date",
    "issecretvalue",
    "strtrim",
    "time",
    "tinsert",
    SlashCmdList = { fields = { NOTES4EVER = { read_only = false } } },
    StaticPopupDialogs = { fields = {
        NOTES4EVER_DELETE = { read_only = false },
        NOTES4EVER_RENAME = { read_only = false },
    } },
}

-- Every addon file opens with `local addonName, ns = ...` (code.md), whether
-- or not it uses the name.
ignore = { "211/addonName" }

-- Specs run in plain Lua 5.1 under busted, where file access is how they read
-- the addon's sources.
files["tests/"] = {
    std = "lua51+busted",
    read_globals = { "io", "require", "loadfile" },
}
