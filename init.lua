-- Copyright (C) 2025 - Diego Iparraguirre
-- Software libre bajo GNU General Public License v3.0 o posterior.
-- https://github.com/diegoiprg/dilware-tool-macSpaces

-- ─────────────────────────────────────────────
-- Dependencias
-- ─────────────────────────────────────────────
local spaces   = require("hs.spaces")
local urlevent = require("hs.urlevent")
local menu     = hs.menubar.new()

-- ─────────────────────────────────────────────
-- Configuración: perfiles (orden garantizado)
-- ─────────────────────────────────────────────
local profile_order = { "personal", "work" }

local profiles = {
    personal = {
        name     = "Personal",
        apps     = { "Safari" },
        space_id = nil,
    },
    work = {
        name     = "Work",
        apps     = { "Microsoft Outlook", "Microsoft Teams", "Google Chrome" },
        space_id = nil,
    },
}

-- ─────────────────────────────────────────────
-- Configuración: retrasos (segundos)
-- ─────────────────────────────────────────────
local delay = {
    short      = 0.5,
    medium     = 1.0,
    app_launch = 1.5,
}

-- ─────────────────────────────────────────────
-- Configuración: navegadores conocidos
-- ─────────────────────────────────────────────
local BROWSER_NAMES = {
    ["com.apple.Safari"]           = "Safari",
    ["com.google.Chrome"]          = "Google Chrome",
    ["com.microsoft.edgemac"]      = "Microsoft Edge",
    ["org.mozilla.firefox"]        = "Firefox",
    ["com.brave.Browser"]          = "Brave",
    ["com.operasoftware.Opera"]    = "Opera",
    ["com.vivaldi.Vivaldi"]        = "Vivaldi",
    ["company.thebrowser.Browser"] = "Arc",
}

-- ─────────────────────────────────────────────
-- Módulo: Log
-- ─────────────────────────────────────────────
local logFilePath = os.getenv("HOME") .. "/.hammerspoon/debug.log"

local function log(msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local f = io.open(logFilePath, "a")
    if f then
        f:write(string.format("[%s] %s\n", timestamp, msg))
        f:close()
    end
end

local function clear_log()
    local f = io.open(logFilePath, "w")
    if f then f:close() end
end

-- ─────────────────────────────────────────────
-- Módulo: Notificaciones
-- ─────────────────────────────────────────────
local function notify(title, msg)
    hs.notify.new({ title = title, informativeText = msg }):send()
    log(string.format("[NOTIFY] %s — %s", title, msg))
end

-- ─────────────────────────────────────────────
-- Módulo: Utilidades
-- ─────────────────────────────────────────────
local function table_contains(tbl, item)
    for _, v in ipairs(tbl) do
        if v == item then return true end
    end
    return false
end

local function is_profile_active(key)
    local p = profiles[key]
    return p ~= nil and p.space_id ~= nil
end

local function browser_display_name(bundle_id)
    return BROWSER_NAMES[bundle_id] or bundle_id
end

-- ─────────────────────────────────────────────
-- Módulo: Navegador predeterminado
-- ─────────────────────────────────────────────

-- Declaración adelantada para permitir referencia desde el submenú
local build_menu

local function set_default_browser(bundle_id)
    local name = browser_display_name(bundle_id)
    -- setDefaultHandler muestra el diálogo de confirmación del sistema.
    -- El cambio solo se aplica si el usuario acepta; no podemos interceptarlo.
    -- Por eso NO actualizamos el menú aquí — se actualiza en la próxima apertura.
    urlevent.setDefaultHandler("http", bundle_id)
    log("[OK] Solicitud de cambio de navegador a " .. name .. " (" .. bundle_id .. ")")
end

local function build_browser_submenu()
    local handlers = urlevent.getAllHandlersForScheme("http")
    local current  = urlevent.getDefaultHandler("http")

    if not handlers or #handlers == 0 then
        return {{ title = "Sin navegadores detectados", disabled = true }}
    end

    -- Ordenar: activo primero, luego alfabético por nombre
    table.sort(handlers, function(a, b)
        if a == current then return true end
        if b == current then return false end
        return browser_display_name(a) < browser_display_name(b)
    end)

    local items = {}
    for _, bundle_id in ipairs(handlers) do
        local name   = browser_display_name(bundle_id)
        local active = (bundle_id == current)

        table.insert(items, {
            title   = (active and "◉  " or "○  ") .. name,
            checked = active,
            fn      = function()
                if not active then
                    set_default_browser(bundle_id)
                end
            end,
        })
    end

    return items
end

-- ─────────────────────────────────────────────
-- Módulo: Menú
-- ─────────────────────────────────────────────
build_menu = function()
    local items = {}

    -- Perfiles en orden garantizado
    for _, key in ipairs(profile_order) do
        local profile = profiles[key]
        if profile then
            local active = is_profile_active(key)
            local label  = (active and "◉  " or "○  ") .. profile.name

            table.insert(items, {
                title = label .. (active and "  —  Cerrar" or "  —  Activar"),
                fn    = function()
                    if active then
                        deactivate_profile(key)
                    else
                        activate_profile(key)
                    end
                end,
            })
        end
    end

    -- Navegador predeterminado
    table.insert(items, { title = "-" })
    table.insert(items, {
        title = "Navegador predeterminado",
        menu  = build_browser_submenu(),
    })

    -- Utilidades
    table.insert(items, { title = "-" })
    table.insert(items, {
        title = "Ver registro",
        fn    = function()
            -- Abre con la app predeterminada para .log (no fuerza TextEdit)
            hs.execute("open " .. logFilePath)
        end,
    })
    table.insert(items, {
        title = "Recargar configuración",
        fn    = hs.reload,
    })

    menu:setTitle("◇")
    menu:setMenu(items)
end

-- ─────────────────────────────────────────────
-- Módulo: Perfiles — Activar
-- ─────────────────────────────────────────────
function activate_profile(key)
    local profile = profiles[key]
    if not profile then
        log("[ERROR] Perfil desconocido: " .. tostring(key))
        return
    end

    if is_profile_active(key) then
        notify("macSpaces", profile.name .. " ya está activo")
        return
    end

    local ok, err = pcall(function() spaces.addSpaceToScreen() end)
    if not ok then
        notify("Error", "No se pudo crear espacio: " .. tostring(err))
        log("[ERROR] addSpaceToScreen falló: " .. tostring(err))
        return
    end

    hs.timer.doAfter(delay.short, function()
        local uuid      = hs.screen.mainScreen():getUUID()
        local all       = spaces.allSpaces()[uuid]

        if not all or #all == 0 then
            notify("Error", "No se encontraron espacios disponibles")
            log("[ERROR] allSpaces vacío para UUID " .. tostring(uuid))
            return
        end

        local new_space = all[#all]
        profile.space_id = new_space
        spaces.gotoSpace(new_space)
        log("[INFO] Espacio " .. tostring(new_space) .. " creado para " .. profile.name)

        hs.timer.doAfter(delay.medium, function()
            -- Lanzar apps de forma secuencial con delay entre cada una
            for i, app_name in ipairs(profile.apps) do
                hs.timer.doAfter(delay.app_launch * (i - 1), function()
                    hs.application.launchOrFocus(app_name)

                    -- Esperar a que la ventana exista antes de moverla
                    hs.timer.doAfter(delay.app_launch, function()
                        local app = hs.application.get(app_name)
                        if not app then
                            log("[WARN] " .. app_name .. " no encontrada tras lanzamiento")
                            return
                        end

                        local win = app:mainWindow()
                        if win then
                            spaces.moveWindowToSpace(win, new_space)
                            log("[OK] " .. app_name .. " movida a espacio " .. tostring(new_space))
                        else
                            log("[WARN] " .. app_name .. " sin ventana principal aún")
                        end
                    end)
                end)
            end

            notify("macSpaces", profile.name .. " activado")
            build_menu()
        end)
    end)
end

-- ─────────────────────────────────────────────
-- Módulo: Perfiles — Desactivar
-- ─────────────────────────────────────────────
function deactivate_profile(key)
    local profile = profiles[key]
    if not profile or not profile.space_id then
        notify("macSpaces", "No hay espacio activo para " .. (profile and profile.name or key))
        return
    end

    local target_space = profile.space_id
    log("[INFO] Cerrando perfil " .. profile.name .. " (espacio " .. tostring(target_space) .. ")")

    -- Cerrar apps del perfil con kill() para cierre limpio (respeta diálogos de guardado)
    for _, app_name in ipairs(profile.apps) do
        local app = hs.application.get(app_name)
        if app then
            app:kill()
            log("[OK] " .. app_name .. " cerrada")
        end
    end

    -- Esperar cierre de apps antes de operar sobre el espacio
    hs.timer.doAfter(delay.medium * 2, function()
        local uuid         = hs.screen.mainScreen():getUUID()
        local all          = spaces.allSpaces()[uuid]

        if not all or #all == 0 then
            log("[ERROR] allSpaces vacío al desactivar " .. profile.name)
            profile.space_id = nil
            build_menu()
            return
        end

        -- Reubicar ventanas ajenas que quedaron en este espacio
        local fallback = all[1]
        for _, win in ipairs(hs.window.allWindows()) do
            local win_spaces = spaces.windowSpaces(win:id())
            if win_spaces and table_contains(win_spaces, target_space) then
                local win_app = win:application()
                if win_app then
                    local app_name = win_app:name()
                    if not table_contains(profile.apps, app_name) then
                        spaces.moveWindowToSpace(win, fallback)
                        log("[OK] Ventana de " .. app_name .. " reubicada al espacio " .. tostring(fallback))
                    end
                end
            end
        end

        spaces.gotoSpace(fallback)

        hs.timer.doAfter(delay.medium, function()
            local ok, err = pcall(function() spaces.removeSpace(target_space) end)

            -- Limpiar space_id independientemente del resultado
            profile.space_id = nil

            if ok then
                log("[OK] Espacio " .. tostring(target_space) .. " eliminado")
                notify("macSpaces", profile.name .. " cerrado")
            else
                log("[ERROR] No se pudo eliminar espacio " .. tostring(target_space) .. ": " .. tostring(err))
                notify("macSpaces", profile.name .. " cerrado (espacio puede requerir limpieza manual)")
            end

            build_menu()
        end)
    end)
end

-- ─────────────────────────────────────────────
-- Inicialización
-- ─────────────────────────────────────────────
clear_log()
log("[INFO] macSpaces v1.3.0 iniciado")
build_menu()
