-- macspaces/launcher.lua
-- Lanzador rápido de aplicaciones configurable.
-- Por defecto vacío; el usuario agrega apps en config.lua.

local M = {}

local utils = require("macspaces.utils")
local cfg   = require("macspaces.config")

-- ─────────────────────────────────────────────
-- API pública
-- ─────────────────────────────────────────────

-- Lanza una aplicación por nombre
function M.launch(app_name)
    local ok = hs.application.launchOrFocus(app_name)
    if ok then
        utils.log("[OK] launcher: lanzado " .. app_name)
    else
        utils.log("[WARN] launcher: no se pudo lanzar " .. app_name)
        utils.notify("macSpaces", "No se pudo abrir " .. app_name)
    end
end

-- Construye el submenú del lanzador
function M.build_submenu()
    local items = {}
    local apps  = (cfg.launcher and cfg.launcher.apps) or {}

    if #apps == 0 then
        table.insert(items, {
            title = "Sin apps configuradas",
            fn    = function() end,
        })
        table.insert(items, { title = "-" })
        table.insert(items, {
            title = "Edita launcher.apps en config.lua",
            fn    = function() end,
        })
        return items
    end

    for _, app in ipairs(apps) do
        -- Cada entrada puede ser string o tabla { name, icon }
        local name = type(app) == "table" and app.name or app
        local icon = type(app) == "table" and (app.icon or "🚀") or "🚀"

        table.insert(items, {
            title = icon .. "  " .. name,
            fn    = function() M.launch(name) end,
        })
    end

    return items
end

return M
