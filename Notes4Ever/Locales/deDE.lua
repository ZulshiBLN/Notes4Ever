local addonName, ns = ...

if GetLocale() ~= "deDE" then return end

ns.L = setmetatable({
    DELETE_CONFIRM   = "\"%s\" löschen?\n%s",
    DELETE_COUNTS    = "%s Ordner und %s Seite(n) werden entfernt.",
    EDITOR_HINT      = "Wähle links eine Seite, oder lege per Rechtsklick auf einen Ordner eine an.",
    MENU_DELETE      = "Löschen",
    MENU_MOVE        = "Verschieben nach",
    MENU_NEW_FOLDER  = "Neuer Ordner",
    MENU_NEW_PAGE    = "Neue Seite",
    MENU_RENAME      = "Umbenennen",
    NEW_FOLDER_TITLE = "Unbenannter Ordner",
    NEW_PAGE_TITLE   = "Unbenannte Seite",
    RENAME_PROMPT    = "Neuer Name:",
    ROOT_ACCOUNT   = "Account-Notizen",
    ROOT_CHARACTER = "Charakter-Notizen",
    STATUS_HEADER  = "%s Version %s",
    STATUS_ROOT    = "%s: %s Notizen, Schema %s, angelegt %s, %s-mal geladen, %s zur Wiederherstellung aufbewahrt",
    USAGE          = "%s: /n4e - Notizbuch öffnen oder schließen; /n4e status - zeigt den Status des Addons",
    WINDOW_TITLE   = "Notes4Ever - Notizbuch",
    WARN_RECOVERY  = "Notes4Ever: %s nicht lesbare Fassung(en) der %s zur Wiederherstellung aufbewahrt. "
                  .. "Kopiere %s und %s.bak jetzt an einen sicheren Ort, vor jedem /reload oder Logout - "
                  .. "das nächste Speichern ersetzt die .bak. Stelle sie bei geschlossenem Spiel wieder her.",
}, { __index = ns.L_enUS })
