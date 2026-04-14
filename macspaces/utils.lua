-- macspaces/utils.lua
-- Utilidades compartidas: log, notificaciones, helpers.

local M = {}

local home        = os.getenv("HOME") or "/tmp"
local logFilePath = home .. "/.hammerspoon/debug.log"
local MAX_LOG_SIZE = 1024 * 1024  -- 1 MB

-- Establece permisos 0600 en un archivo
local function set_permissions_600(path)
    os.execute("chmod 600 " .. path .. " 2>/dev/null")
end

-- Rota el log si excede el tamaño máximo
local function rotate_log_if_needed()
    local f = io.open(logFilePath, "r")
    if not f then return end
    local size = f:seek("end")
    f:close()
    if size and size > MAX_LOG_SIZE then
        os.remove(logFilePath .. ".old")
        os.rename(logFilePath, logFilePath .. ".old")
        set_permissions_600(logFilePath .. ".old")
    end
end

-- Ofusca últimos octetos de IPs en el mensaje de log
local function mask_ip(msg)
    -- IPv4: reemplaza último octeto con ***
    return msg:gsub("(%d+%.%d+%.%d+%.)%d+", "%1***")
end

-- Escribe una línea en el archivo de log
function M.log(msg)
    rotate_log_if_needed()
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local f = io.open(logFilePath, "a")
    if f then
        f:write(string.format("[%s] %s\n", timestamp, mask_ip(msg)))
        f:close()
        set_permissions_600(logFilePath)
    end
end

-- Limpia el archivo de log
function M.clear_log()
    local f = io.open(logFilePath, "w")
    if f then f:close() end
    set_permissions_600(logFilePath)
end

-- Muestra una notificación del sistema y la registra en el log
function M.notify(title, msg)
    hs.notify.new({ title = title, informativeText = msg }):send()
    M.log(string.format("[NOTIFY] %s — %s", title, msg))
end

-- Canvas persistente para alertas de larga duración
local _alert_canvas = nil
local _alert_timer  = nil

local function dismiss_alert_canvas()
    if _alert_timer  then _alert_timer:stop();   _alert_timer  = nil end
    if _alert_canvas then _alert_canvas:delete(); _alert_canvas = nil end
end

local function show_alert_canvas(title, msg, duration)
    dismiss_alert_canvas()

    local text    = title .. "\n\n" .. msg
    local styled  = hs.styledtext.new(text, {
        font  = { name = ".AppleSystemUIFont", size = 15 },
        color = { white = 1, alpha = 1 },
    })
    local screen  = hs.screen.mainScreen():fullFrame()
    local pad     = 24
    local max_w   = math.min(520, screen.w - pad * 2)
    local size    = hs.drawing.getTextDrawingSize(styled) or { w = max_w, h = 200 }
    local cw      = math.min(size.w + pad * 2, max_w + pad * 2)
    local ch      = size.h + pad * 2
    local cx      = screen.x + (screen.w - cw) / 2
    local cy      = screen.y + screen.h * 0.25

    _alert_canvas = hs.canvas.new({ x = cx, y = cy, w = cw, h = ch })
    _alert_canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    _alert_canvas:level(hs.canvas.windowLevels.floating)
    _alert_canvas:clickActivating(false)
    _alert_canvas[1] = {
        type             = "rectangle",
        fillColor        = { red = 0.10, green = 0.10, blue = 0.10, alpha = 0.92 },
        strokeColor      = { white = 1, alpha = 0.15 },
        strokeWidth      = 1,
        roundedRectRadii = { xRadius = 12, yRadius = 12 },
        action           = "strokeAndFill",
    }
    _alert_canvas[2] = {
        type  = "text",
        text  = styled,
        frame = { x = pad, y = pad, w = cw - pad * 2, h = ch - pad * 2 },
    }
    _alert_canvas:show()
    _alert_timer = hs.timer.doAfter(duration, dismiss_alert_canvas)
end

-- Notificación llamativa: sonido del sistema + canvas persistente + notificación estándar
function M.alert_notify(title, msg, duration)
    M.notify(title, msg)
    show_alert_canvas(title, msg, duration or 4)
    local sound = hs.sound.getByName("Glass")
    if sound then sound:play() end
end

-- Verifica si un valor existe en una tabla indexada
function M.table_contains(tbl, item)
    for _, v in ipairs(tbl) do
        if v == item then return true end
    end
    return false
end

-- Helper compartido: ítem informativo que copia su valor al portapapeles al hacer clic
function M.info_item(label, value)
    return {
        title = label .. value,
        fn    = function() hs.pasteboard.setContents(value) end,
    }
end

-- Helper: ítem puramente informativo (no accionable)
function M.disabled_item(label)
    return { title = label, disabled = true }
end

-- Formatea segundos como HH:MM:SS (o MM:SS si menos de una hora)
function M.format_time(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

return M
