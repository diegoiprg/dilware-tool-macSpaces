-- Copyright (C) 2025 - Diego Iparraguirre
-- Software libre bajo GNU General Public License v3.0 o posterior.
-- https://github.com/diegoiprg/dilware-tool-macSpaces

-- ─────────────────────────────────────────────
-- Punto de entrada de macSpaces v2.4.0
-- Carga módulos y arranca el sistema.
-- ─────────────────────────────────────────────

local hs_dir = os.getenv("HOME") .. "/.hammerspoon"
-- Evitar duplicar rutas en package.path en recargas sucesivas (hs.reload)
local hs_lua_path = hs_dir .. "/?.lua"
if not package.path:find(hs_lua_path, 1, true) then
    package.path = hs_lua_path .. ";" ..
                   hs_dir .. "/?/init.lua;" ..
                   package.path
end

local utils     = require("macspaces.utils")
local cfg       = require("macspaces.config")
local hotkeys   = require("macspaces.hotkeys")
local clipboard = require("macspaces.clipboard")
local network   = require("macspaces.network")
local vpn       = require("macspaces.vpn")
local menu      = require("macspaces.menu")

utils.clear_log()
utils.log("[INFO] macSpaces v" .. cfg.VERSION .. " iniciado")

-- El portapapeles captura entradas en segundo plano (sin reconstruir el menú)
clipboard.start()

-- Red y VPN obtienen datos en segundo plano (sin reconstruir el menú)
-- El menú se construye on-demand al abrirse, siempre con datos frescos
network.refresh()
vpn.refresh()

-- Registrar hotkeys globales
hotkeys.register(function() menu.build() end)

-- Inicializar menú (setMenu con función on-demand)
menu.init()
