-- macspaces/bluetooth.lua
-- Lista dispositivos Bluetooth conectados con información de batería.
-- Usa ioreg (herramienta nativa de macOS) para leer datos del sistema.

local M = {}

local utils = require("macspaces.utils")

-- ─────────────────────────────────────────────
-- Lectura via ioreg
-- ─────────────────────────────────────────────

-- Parsea la salida de ioreg y devuelve tabla de dispositivos
local function parse_ioreg()
    local output = hs.execute(
        "ioreg -r -k BatteryPercent -l 2>/dev/null | " ..
        "grep -E '\"(Product|BatteryPercent|DeviceAddress|BatteryStatus)\"'"
    )

    local devices = {}
    local current = {}

    for line in output:gmatch("[^\n]+") do
        local key, val = line:match('"(%w+)"%s*=%s*(.+)')
        if key and val then
            val = val:gsub('^"', ""):gsub('"$', ""):gsub("%s+$", "")

            if key == "Product" then
                if current.name then
                    table.insert(devices, current)
                end
                current = { name = val }
            elseif key == "BatteryPercent" then
                current.battery = tonumber(val)
            elseif key == "DeviceAddress" then
                current.address = val
            elseif key == "BatteryStatus" then
                current.status = val
            end
        end
    end

    if current.name then
        table.insert(devices, current)
    end

    return devices
end

-- ─────────────────────────────────────────────
-- Helpers de presentación
-- ─────────────────────────────────────────────

local function battery_icon(pct)
    if not pct then return "🔵" end
    if pct >= 80 then return "🔋" end
    if pct >= 40 then return "🔋" end
    if pct >= 20 then return "🪫" end
    return "🪫"
end

local function battery_label(device)
    if device.battery then
        return string.format("%s %d%%", battery_icon(device.battery), device.battery)
    end
    return "Sin datos de batería"
end

-- ─────────────────────────────────────────────
-- API pública
-- ─────────────────────────────────────────────

function M.devices()
    local ok, result = pcall(parse_ioreg)
    if not ok then
        utils.log("[ERROR] bluetooth: " .. tostring(result))
        return {}
    end
    return result
end

-- Construye el submenú de Bluetooth
function M.build_submenu()
    local devices = M.devices()
    local items   = {}

    if #devices == 0 then
        table.insert(items, {
            title    = "Sin dispositivos Bluetooth conectados",
            disabled = true,
        })
        return items
    end

    for _, dev in ipairs(devices) do
        -- Nombre del dispositivo
        table.insert(items, {
            title    = "🎧  " .. (dev.name or "Dispositivo desconocido"),
            disabled = true,
        })
        -- Batería
        table.insert(items, {
            title    = "    " .. battery_label(dev),
            disabled = true,
        })
        -- Dirección BT si está disponible
        if dev.address then
            table.insert(items, {
                title    = "    " .. dev.address,
                disabled = true,
            })
        end
        table.insert(items, { title = "-" })
    end

    -- Quitar el último separador
    if #items > 0 and items[#items].title == "-" then
        table.remove(items)
    end

    return items
end

return M
