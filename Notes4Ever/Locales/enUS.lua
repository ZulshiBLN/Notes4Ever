local addonName, ns = ...

-- enUS is the authority: it defines every key. Other locales override what
-- they translate; the per-key fallback to these strings arrives with them.
ns.L = {
    STATUS_LINE  = "%s %s - account notes: %s, character notes: %s",
    STATE_STORED = "stored",
    STATE_NONE   = "none yet",
    USAGE        = "%s: /n4e status - show the addon's status",
}
