local addonName, ns = ...

-- enUS is the authority: it defines every key. Another locale replaces ns.L
-- with its own table and falls back to this one per key, so a string it has
-- not translated yet shows in English rather than as an error.
ns.L_enUS = {
    DELETE_CONFIRM   = "Delete \"%s\"?\n%s",
    DELETE_COUNTS    = "%s folder(s) and %s page(s) will be removed.",
    MENU_DELETE      = "Delete",
    MENU_MOVE        = "Move to",
    MENU_NEW_FOLDER  = "New folder",
    MENU_NEW_PAGE    = "New page",
    MENU_RENAME      = "Rename",
    NEW_FOLDER_TITLE = "Untitled folder",
    NEW_PAGE_TITLE   = "Untitled page",
    RENAME_PROMPT    = "New name:",
    ROOT_ACCOUNT   = "Account notes",
    ROOT_CHARACTER = "Character notes",
    STATUS_HEADER  = "%s %s",
    STATUS_ROOT    = "%s: %s notes, schema %s, created %s, loaded %s times, %s kept for recovery",
    USAGE          = "%s: /n4e - open or close the notebook; /n4e status - show the addon's status",
    WINDOW_TITLE   = "Notes4Ever - Notebook",
    WARN_RECOVERY  = "Notes4Ever: %s set(s) of %s could not be read and are kept for recovery. "
                  .. "Copy %s and %s.bak somewhere safe now, before any /reload or logout - "
                  .. "the next save replaces the .bak. Restore them with the game closed.",
}
ns.L = ns.L_enUS
