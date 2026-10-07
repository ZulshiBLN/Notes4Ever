local addonName, ns = ...

if GetLocale() ~= "deDE" then return end

ns.L = setmetatable({
    STATUS_LINE  = "%s %s - Account-Notizen: %s, Charakter-Notizen: %s",
    STATE_STORED = "gespeichert",
    STATE_NONE   = "noch keine",
    USAGE        = "%s: /n4e status - zeigt den Status des Addons",
}, { __index = ns.L_enUS })
