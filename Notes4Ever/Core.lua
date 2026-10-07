local addonName, ns = ...

local L = ns.L

-- Read from the TOC rather than repeated here: the version lives in one place.
local version = C_AddOns.GetAddOnMetadata(addonName, "Version")

-- SavedVariables are only filled in once the client has loaded this addon, so
-- they are looked at when the status is asked for, never at file scope.
local function stateOf(saved)
    return saved and L.STATE_STORED or L.STATE_NONE
end

function ns.PrintStatus()
    print(L.STATUS_LINE:format(addonName, version,
        stateOf(Notes4EverDB), stateOf(Notes4EverCharDB)))
end

SLASH_NOTES4EVER1 = "/n4e"
SLASH_NOTES4EVER2 = "/notes"
SlashCmdList.NOTES4EVER = function(input)
    local command = strtrim(input or ""):lower()
    if command == "" or command == "status" then
        ns.PrintStatus()
    else
        print(L.USAGE:format(addonName))
    end
end

-- Named in the TOC's AddonCompartmentFunc, so it has to be a global.
function Notes4Ever_OnAddonCompartmentClick()
    ns.PrintStatus()
end
