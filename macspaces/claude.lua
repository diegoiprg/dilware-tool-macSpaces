-- macspaces/claude.lua
-- Monitor de uso de Claude Code y Claude.ai
-- Fuente: ~/.claude/history.jsonl (Claude Code) + cookie Safari (Claude.ai)

local M = {}

local utils = require("macspaces.utils")

-- ── Cache ──────────────────────────────────────────────────────────────────
local cache = {
    data     = nil,  -- { five_hour = {pct, reset}, seven_day = {pct, reset}, source }
    last_fetch = 0,
    ttl      = 60,   -- segundos entre refetches
}

-- ── Helpers ────────────────────────────────────────────────────────────────

-- Formatea segundos restantes como "Xh Ym" o "Ym"
local function fmt_reset(epoch)
    if not epoch or epoch == 0 then return "—" end
    local remaining = epoch - os.time()
    if remaining <= 0 then return "ahora" end
    local h = math.floor(remaining / 3600)
    local m = math.floor((remaining % 3600) / 60)
    if h > 0 then return h .. "h " .. m .. "m" end
    return m .. "m"
end

-- Lee el último archivo JSONL de Claude Code y extrae rate_limits
local function read_from_claude_code()
    local home = os.getenv("HOME") or ""
    local claude_dir = home .. "/.claude"

    -- Buscar el jsonl más reciente en projects/
    local handle = io.popen(
        "find '" .. claude_dir .. "/projects' -name '*.jsonl' " ..
        "! -path '*/subagents/*' -newer '" .. claude_dir .. "/history.jsonl' " ..
        "2>/dev/null | head -1"
    )
    local latest = handle and handle:read("*l")
    if handle then handle:close() end

    -- Fallback a history.jsonl
    if not latest or latest == "" then
        latest = claude_dir .. "/history.jsonl"
    end

    local f = io.open(latest, "r")
    if not f then return nil end

    -- Leer las últimas líneas buscando rate_limits
    local lines = {}
    for line in f:lines() do
        table.insert(lines, line)
        if #lines > 200 then table.remove(lines, 1) end
    end
    f:close()

    -- Buscar en reversa la entrada más reciente con rate_limits
    for i = #lines, 1, -1 do
        local ok, data = pcall(hs.json.decode, lines[i])
        if ok and data then
            local rl = data.rate_limits or
                       (data.message and data.message.rate_limits) or
                       (data.summary and data.summary.rate_limits)
            if rl and rl.five_hour then
                return {
                    five_hour = {
                        pct   = math.floor(rl.five_hour.used_percentage or 0),
                        reset = rl.five_hour.resets_at or 0,
                    },
                    seven_day = {
                        pct   = math.floor((rl.seven_day and rl.seven_day.used_percentage) or 0),
                        reset = (rl.seven_day and rl.seven_day.resets_at) or 0,
                    },
                    source = "code",
                }
            end
        end
    end
    return nil
end

-- Obtiene cookie de sesión de Safari para claude.ai
local function get_safari_cookie()
    local home = os.getenv("HOME") or ""
    -- Safari guarda cookies en BinaryCookies — necesitamos python para leerlo
    local cmd = [[python3 -c "
import subprocess, sys
try:
    r = subprocess.run(
        ['python3', '-c',
         'import http.cookiejar, urllib.request; j=http.cookiejar.MozillaCookieJar(); '
         'print(\"ok\")'],
        capture_output=True)
    # Intentar leer cookie via osascript/safari
    import os
    cookie_db = os.path.expanduser(
        '~/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies')
    if os.path.exists(cookie_db):
        print('found')
    else:
        print('notfound')
except:
    print('error')
" 2>/dev/null]]
    -- Por ahora retorna nil — la autenticación Safari requiere un helper separado
    -- que se implementará en la siguiente iteración
    return nil
end

-- Fetch principal: intenta Claude Code primero, luego API web
function M.fetch()
    local now = os.time()
    if cache.data and (now - cache.last_fetch) < cache.ttl then
        return cache.data
    end

    local data = read_from_claude_code()
    if not data then
        -- Sin sesión activa de Claude Code
        data = { source = "none" }
    end

    cache.data = data
    cache.last_fetch = now
    return data
end

function M.invalidate()
    cache.data = nil
    cache.last_fetch = 0
end

-- ── UI helpers ──────────────────────────────────────────────────────────────

-- Barra de progreso en texto: ████░░░░ 74%
local function bar(pct, width)
    width = width or 8
    local filled = math.floor((pct / 100) * width)
    local empty = width - filled
    return string.rep("█", filled) .. string.rep("░", empty)
end

-- Color semáforo según porcentaje
function M.color_for(pct)
    if pct >= 85 then
        return { red = 0.85, green = 0.20, blue = 0.15, alpha = 0.85 }  -- rojo
    elseif pct >= 60 then
        return { red = 0.90, green = 0.65, blue = 0.10, alpha = 0.85 }  -- amarillo
    else
        return { red = 0.15, green = 0.50, blue = 0.30, alpha = 0.85 }  -- verde oscuro
    end
end

-- Texto de la fila para el overlay
function M.overlay_label()
    local d = M.fetch()
    if d.source == "none" or not d.five_hour then
        return "✦ Claude  —  sin sesión activa"
    end
    local fh = d.five_hour
    local b = bar(fh.pct, 8)
    local reset = fmt_reset(fh.reset)
    return string.format("✦ Claude  %s %d%%  ↺%s", b, fh.pct, reset)
end

-- Construye el submenú para menu.lua
function M.build_submenu()
    local d = M.fetch()
    local items = {}

    if d.source == "none" or not d.five_hour then
        table.insert(items, utils.disabled_item("Sin sesión activa de Claude Code"))
        table.insert(items, {
            title = "Abrir claude.ai/settings/usage",
            fn    = function()
                hs.urlevent.openURL("https://claude.ai/settings/usage")
            end,
        })
        return items
    end

    local fh = d.five_hour
    local sd = d.seven_day or { pct = 0, reset = 0 }

    -- Ventana 5 horas
    table.insert(items, utils.disabled_item(
        string.format("5h   %s %d%%", bar(fh.pct, 10), fh.pct)
    ))
    table.insert(items, utils.disabled_item(
        "     Reset en " .. fmt_reset(fh.reset)
    ))

    -- Ventana 7 días
    if sd.pct > 0 then
        table.insert(items, { title = "-" })
        table.insert(items, utils.disabled_item(
            string.format("7d   %s %d%%", bar(sd.pct, 10), sd.pct)
        ))
        table.insert(items, utils.disabled_item(
            "     Reset en " .. fmt_reset(sd.reset)
        ))
    end

    -- Acciones
    table.insert(items, { title = "-" })
    table.insert(items, {
        title = "Abrir uso detallado",
        fn    = function()
            hs.urlevent.openURL("https://claude.ai/settings/usage")
        end,
    })
    table.insert(items, {
        title = "Actualizar",
        fn    = function() M.invalidate() end,
    })

    return items
end

return M
