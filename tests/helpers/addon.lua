-- Runs addon files as the client does: each gets the addon's name and the
-- shared namespace as its arguments. `env` adds or stubs globals - GetLocale,
-- say - on top of plain Lua; nothing else of WoW exists here.
local M = {}

function M.read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

function M.run(source, name, ns, env)
    local chunk = assert(loadstring(source, name))
    setfenv(chunk, setmetatable(env or {}, { __index = _G }))
    chunk("Notes4Ever", ns)
    return ns
end

function M.load(path, ns, env)
    return M.run(M.read(path), path, ns or {}, env)
end

return M
