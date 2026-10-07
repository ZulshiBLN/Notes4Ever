local addonName, ns = ...

-- enUS is the authority: it defines every key. Another locale replaces ns.L
-- with its own table and falls back to this one per key, so a string it has
-- not translated yet shows in English rather than as an error.
ns.L_enUS = {
    STATUS_LINE  = "%s %s - account notes: %s, character notes: %s",
    STATE_STORED = "stored",
    STATE_NONE   = "none yet",
    USAGE        = "%s: /n4e status - show the addon's status",
}
ns.L = ns.L_enUS
