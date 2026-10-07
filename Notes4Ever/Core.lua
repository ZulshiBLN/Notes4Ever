local addonName, ns = ...

local L, Storage = ns.L, ns.Storage

-- Read from the TOC rather than repeated here: the version lives in one place.
local version = C_AddOns.GetAddOnMetadata(addonName, "Version")

-- Whether each SavedVariable arrived empty, noted at ADDON_LOADED and used at
-- PLAYER_LOGIN, when the character's GUID is known.
local arrived = {}

-- Unit identity may be a secret value on Forever; a secret cannot be a
-- table key, so such a session records no count.
local function playerGuid()
    local guid = UnitGUID("player")
    if issecretvalue and issecretvalue(guid) then return nil end
    return guid
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        -- The client has just filled the SavedVariables; this is the first
        -- moment they can be read, and the only place they are replaced.
        arrived.accountArrivedNil = Notes4EverDB == nil
        arrived.characterArrivedNil = Notes4EverCharDB == nil
        Notes4EverDB = Storage.load(Notes4EverDB, time())
        Notes4EverCharDB = Storage.load(Notes4EverCharDB, time())
    elseif event == "PLAYER_LOGIN" then
        Storage.reconcile(Notes4EverDB, Notes4EverCharDB, playerGuid(), time(), arrived)
        for _, message in ipairs(Storage.warnings(Notes4EverDB, Notes4EverCharDB, L)) do
            print(message)
        end
    elseif event == "PLAYER_LOGOUT" then
        -- The last moment before the client writes the SavedVariables - on
        -- /reload too. Typed text is written, then this session's notes are
        -- counted, so a later loss of either file is noticed.
        ns.Editor.Flush()
        Storage.reconcile(Notes4EverDB, Notes4EverCharDB, playerGuid(), time())
    end
end)

local function rootStatus(label, db)
    return L.STATUS_ROOT:format(label, Storage.count(db), db.schemaVersion,
        date("%Y-%m-%d %H:%M:%S", db.root.created), db.loads, #(db.recovery or {}))
end

function ns.PrintStatus()
    print(L.STATUS_HEADER:format(addonName, version))
    print(rootStatus(L.ROOT_ACCOUNT, Notes4EverDB))
    print(rootStatus(L.ROOT_CHARACTER, Notes4EverCharDB))
end

SLASH_NOTES4EVER1 = "/n4e"
SLASH_NOTES4EVER2 = "/notes"
SlashCmdList.NOTES4EVER = function(input)
    local command = strtrim(input or ""):lower()
    if command == "" then
        ns.Window.Toggle()
    elseif command == "status" then
        ns.PrintStatus()
    else
        print(L.USAGE:format(addonName))
    end
end

-- Named in the TOC's AddonCompartmentFunc, so it has to be a global.
function Notes4Ever_OnAddonCompartmentClick()
    ns.Window.Toggle()
end
