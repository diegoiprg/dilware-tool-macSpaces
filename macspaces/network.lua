-- macspaces/network.lua
-- Información de red: interfaz activa, IP local, IP externa, país, ISP.
-- La IP externa se obtiene de forma asíncrona via ip-api.com (gratuito).

local M = {}

local utils = require("macspaces.utils")

-- ─────────────────────────────────────────────
-- Estado en caché (se refresca cada 60 segundos)
-- ─────────────────────────────────────────────
local cache = {
    local_info  = nil,   -- datos de interfaz local
    remote_info = nil,   -- datos de ip-api.com
    fetching    = false,
    last_fetch  = 0,
    ttl         = 60,    -- segundos antes de refrescar
}

-- ─────────────────────────────────────────────
-- Información local (sin red externa)
-- ─────────────────────────────────────────────

local function get_local_info()
    local info = {}

    -- Interfaz activa y tipo (WiFi o Ethernet)
    local ifaces = hs.network.interfaces()
    local primary = hs.network.primaryInterfaces and hs.network.primaryInterfaces()

    -- Detectar interfaz primaria activa
    local active_iface = nil
    for _, iface in ipairs(ifaces or {}) do
        local details = hs.network.interfaceDetails(iface)
        if details and details["IPv4"] then
            active_iface = iface
            break
        end
    end

    if active_iface then
        info.interface = active_iface
        -- en0 = WiFi, en1+ = Ethernet en la mayoría de Macs
        if active_iface:match("^en0") then
            info.type = "WiFi"
        elseif active_iface:match("^en") then
            info.type = "Ethernet"
        elseif active_iface:match("^utun") or active_iface:match("^ppp") then
            info.type = "VPN"
        else
            info.type = active_iface
        end

        local details = hs.network.interfaceDetails(active_iface)
        if details and details["IPv4"] then
            local addrs = details["IPv4"]["Addresses"]
            if addrs and #addrs > 0 then
                info.local_ip = addrs[1]
            end
        end
    end

    -- SSID de WiFi si aplica
    local wifi = hs.wifi.currentNetwork and hs.wifi.currentNetwork()
    if wifi then
        info.ssid = wifi
    end

    -- Velocidad de interfaz via networksetup
    if active_iface then
        local speed_out = hs.execute(
            "networksetup -getinfo " .. active_iface .. " 2>/dev/null | grep 'Link Speed'"
        )
        local speed = speed_out:match("Link Speed:%s*(.+)")
        if speed then info.speed = speed:gsub("%s+$", "") end
    end

    return info
end

-- ─────────────────────────────────────────────
-- Información remota via ip-api.com (asíncrona)
-- ─────────────────────────────────────────────

local function fetch_remote_info(on_done)
    if cache.fetching then return end
    local now = os.time()
    if cache.remote_info and (now - cache.last_fetch) < cache.ttl then
        if on_done then on_done() end
        return
    end

    cache.fetching = true
    utils.log("[INFO] network: consultando ip-api.com...")

    hs.http.asyncGet(
        "http://ip-api.com/json/?fields=status,query,country,countryCode,regionName,city,isp,org,as,proxy,hosting",
        nil,
        function(status, body, _)
            cache.fetching = false
            if status == 200 and body then
                local ok, data = pcall(function() return hs.json.decode(body) end)
                if ok and data and data.status == "success" then
                    cache.remote_info = data
                    cache.last_fetch  = os.time()
                    utils.log("[OK] network: IP externa " .. (data.query or "?"))
                else
                    utils.log("[WARN] network: respuesta inválida de ip-api.com")
                end
            else
                utils.log("[WARN] network: no se pudo obtener IP externa (status " .. tostring(status) .. ")")
            end
            if on_done then on_done() end
        end
    )
end

-- ─────────────────────────────────────────────
-- API pública
-- ─────────────────────────────────────────────

function M.refresh(on_done)
    cache.local_info = get_local_info()
    fetch_remote_info(on_done)
end

function M.local_info()
    if not cache.local_info then
        cache.local_info = get_local_info()
    end
    return cache.local_info
end

function M.remote_info()
    return cache.remote_info
end

-- Construye el submenú de red
function M.build_submenu(on_update)
    local local_i  = M.local_info()
    local remote_i = M.remote_info()
    local items    = {}

    -- ── Conexión local ────────────────────────
    local type_icon = ({ WiFi = "📶", Ethernet = "🔌", VPN = "🔒" })[local_i.type or ""] or "🌐"

    table.insert(items, {
        title    = type_icon .. "  " .. (local_i.type or "Sin conexión"),
        disabled = true,
    })

    if local_i.ssid then
        table.insert(items, { title = "    Red: " .. local_i.ssid, disabled = true })
    end
    if local_i.local_ip then
        table.insert(items, { title = "    IP local: " .. local_i.local_ip, disabled = true })
    end
    if local_i.speed then
        table.insert(items, { title = "    Velocidad: " .. local_i.speed, disabled = true })
    end

    -- ── IP externa ────────────────────────────
    table.insert(items, { title = "-" })

    if remote_i then
        table.insert(items, { title = "🌍  IP externa", disabled = true })
        table.insert(items, { title = "    IP: " .. (remote_i.query or "?"), disabled = true })
        table.insert(items, { title = "    País: " .. (remote_i.country or "?"), disabled = true })
        table.insert(items, { title = "    Región: " .. (remote_i.regionName or "?"), disabled = true })
        table.insert(items, { title = "    Ciudad: " .. (remote_i.city or "?"), disabled = true })
        table.insert(items, { title = "    ISP: " .. (remote_i.isp or "?"), disabled = true })
        table.insert(items, { title = "    Operador: " .. (remote_i.org or "?"), disabled = true })

        if remote_i.proxy or remote_i.hosting then
            table.insert(items, { title = "    ⚠️  Proxy/VPN detectado", disabled = true })
        end
    else
        table.insert(items, { title = "    Obteniendo IP externa…", disabled = true })
    end

    -- ── Refrescar ─────────────────────────────
    table.insert(items, { title = "-" })
    table.insert(items, {
        title = "Actualizar",
        fn    = function()
            cache.remote_info = nil
            cache.local_info  = nil
            M.refresh(on_update)
            if on_update then on_update() end
        end,
    })

    return items
end

return M
