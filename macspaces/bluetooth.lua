-- macspaces/bluetooth.lua
-- Lista dispositivos Bluetooth conectados con información de batería.
-- Usa ioreg (herramienta nativa de macOS) para leer datos del sistema.

local M = {}

local utils = require("macspaces.utils")

-- ─────────────────────────────────────────────
-- Lectura via ioreg
-- ─────────────────────────────────────────────

local function parse_ioreg()
    local output = hs.execute(
        "ioreg -r -k BatteryPercent -l 2>/dev/null | " ..
        "grep -E '\"(Product|BatteryPercent|DeviceAddress)\"'"
    )

    local devices = {}
    local current = {}

    for line in output:gmatch("[^\n]+") do
        -- Extraer clave y valor de líneas tipo: "Product" = "AirPods Pro"
        local key, val = line:match('"(%w+)"%s*=%s*"([^"]*)"')
        if not key then
            -- Intentar con valor numérico: "BatteryPercent" = 85
            key, val = line:match('"(%w+)"%s*=%s*(%d+)')
        end

        if key and val then
            if key == "Product" then
                -- Guardar dispositivo anterior si existe
                if current.name then
                    table.insert(devices, current)
                end
                current = { name = val }
            elseif key == "BatteryPercent" then
                current.battery = tonumber(val)
            elseif key == "DeviceAddress" then
                current.address = val
            end
        end
    end

    -- Guardar el último dispositivo
    if current.name then
        table.insert(devices, current)
    end

    -- Eliminar duplicados por nombre
    local seen = {}
    local unique = {}
    for _, dev in ipairs(devices) do
        if not seen[dev.name] then
            seen[dev.name] = true
            table.insert(unique, dev)
        end
    end

    return unique
end

-- ─────────────────────────────────────────────
-- Helpers de presentación
-- ─────────────────────────────────────────────

local function battery_icon(pct)
    if not pct then return "○" end
    if pct >= 80 then return "🔋" end
    if pct >= 20 then return "🔋" end
    return "🪫"
end

local function battery_label(device)
    if device.battery then
        return string.format("%s  %d%%", battery_icon(device.battery), device.battery)
    end
    return "Sin datos de batería"
end

-- Ícono según tipo de dispositivo (heurística por nombre)
local function device_icon(name)
    local lower = name:lower()
    if lower:match("airpod") or lower:match("headphone") or lower:match("auricular") then
        return "🎧"
    elseif lower:match("mouse") or lower:match("magic mouse") then
        return "🖱"
    elseif lower:match("keyboard") or lower:match("teclado") then
        return "⌨️"
    elseif lower:match("trackpad") then
        return "⬜"
    elseif lower:match("speaker") or lower:match("altavoz") then
        return "🔊"
    end
    return "📱"
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

    for i, dev in ipairs(devices) do
        local icon = device_icon(dev.name)
        table.insert(items, {
            title    = icon .. "  " .. dev.name,
            disabled = true,
        })
        table.insert(items, {
            title    = "    Batería: " .. battery_label(dev),
            disabled = true,
        })
        -- Separador entre dispositivos (no al final)
        if i < #devices then
            table.insert(items, { title = "-" })
        end
    end

    return items
end

return M
