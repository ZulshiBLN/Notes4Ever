local addonName, ns = ...

-- enUS is the authority: it defines every key. Another locale replaces ns.L
-- with its own table and falls back to this one per key, so a string it has
-- not translated yet shows in English rather than as an error.
ns.L_enUS = {
    ROOT_ACCOUNT   = "Account notes",
    ROOT_CHARACTER = "Character notes",
    STATUS_HEADER  = "%s %s",
    STATUS_ROOT    = "%s: schema %s, created %s, loaded %s times, %s kept for recovery",
    USAGE          = "%s: /n4e status - show the addon's status",
    WARN_RECOVERY  = "Notes4Ever: %s set(s) of %s could not be read and are kept for recovery. "
                  .. "Copy %s and %s.bak somewhere safe now, before any /reload or logout - "
                  .. "the next save may replace the .bak. Restore them with the game closed.",
}
ns.L = ns.L_enUS
