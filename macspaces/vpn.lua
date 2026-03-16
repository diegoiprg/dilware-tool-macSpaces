-- macspaces/vpn.lua
-- Detección de VPN activa: interfaces utun*/ppp*, IP del túnel,
-- información geográfica via ip-api.com (reutiliza caché de network.lua).

local M = {}

local utils = require("macspaces.utils")

-- ─────────────────────────────────────────────
-- Detección de interfaces VPN
-- ─────────────────────────────────────────────

-- Devuelve tabla con las interfaces VPN activas y sus IPs
local function detect_vpn_interfaces()
    local vpn_ifaces = {}
    local ifaces = hs.network.interfaces()
    if not ifaces then return vpn_ifaces end

    for _, iface in ipairs(ifaces) do
        -- utun* = WireGuard, IKEv2, OpenVPN TUN; ppp* = L2TP, PPTP
        if iface:match("^utun") or iface:match("^ppp") then
            local details = hs.network.interfaceDetails(iface)
            if details and details["IPv4"] then
                local addrs = details["IPv4"]["Addresses"]
                local ip = (addrs and #addrs > 0) and addrs[1] or nil
                table.insert(vpn_ifaces, { interface = iface, ip = ip })
            end
        end
    end

    return vpn_ifaces
end

-- ─────────────────────────────────────────────
-- Caché de información remota de la IP del túnel
-- ─────────────────────────────────────────────

local cache = {
    data      = nil,
    fetching  = false,
    last_ip   = nil,   -- IP consultada; si cambia, se invalida
    last_fetch = 0,
    ttl        = 120,  -- segundos
}

local function fetch_tunnel_info(tunnel_ip, on_done)
    if cache.fetching then return end

    local now = os.time()
    -- Reusar caché si la IP no cambió y no expiró
    if cache.data and cache.last_ip == tunnel_ip and (now - cache.last_fetch) < cache.ttl then
        if on_done then on_done() end
        return
    end

    cache.fetching = true
    utils.log("[INFO] vpn: consultando ip-api.com para " .. (tunnel_ip or "?"))

    local url = "http://ip-api.com/json/" .. (tunnel_ip or "") ..
                "?fields=status,query,country,countryCode,regionName,city,isp,org,as,proxy,hosting"

    hs.http.asyncGet(url, nil, function(status, body, _)
        cache.fetching = false
        if status == 200 and body then
            local ok, data = pcall(function() return hs.json.decode(body) end)
            if ok and data and data.status == "success" then
                cache.data       = data
                cache.last_ip    = tunnel_ip
                cache.last_fetch = os.time()
                utils.log("[OK] vpn: info obtenida para " .. (data.query or "?"))
            else
                utils.log("[WARN] vpn: respuesta inválida de ip-api.com")
            end
        else
            utils.log("[WARN] vpn: no se pudo consultar ip-api.com (status " .. tostring(status) .. ")")
        end
        if on_done then on_done() end
    end)
end

-- ─────────────────────────────────────────────
-- API pública
-- ─────────────────────────────────────────────

-- Devuelve true si hay al menos una interfaz VPN activa
function M.is_active()
    return #detect_vpn_interfaces() > 0
end

-- Devuelve la lista de interfaces VPN activas
function M.interfaces()
    return detect_vpn_interfaces()
end

-- Refresca la información remota del túnel
function M.refresh(on_done)
    local ifaces = detect_vpn_interfaces()
    if #ifaces > 0 and ifaces[1].ip then
        fetch_tunnel_info(ifaces[1].ip, on_done)
    else
        cache.data = nil
        if on_done then on_done() end
    end
end

-- Construye el submenú de VPN
function M.build_submenu(on_update)
    local ifaces = detect_vpn_interfaces()
    local items  = {}

    if #ifaces == 0 then
        table.insert(items, { title = "🔓  Sin VPN activa", disabled = true })
        return items
    end

    -- Estado general
    table.insert(items, {
        title    = "🔒  VPN activa (" .. #ifaces .. " interfaz" .. (#ifaces > 1 and "es" or "") .. ")",
        disabled = true,
    })
    table.insert(items, { title = "-" })

    -- Detalle por interfaz
    for _, iface in ipairs(ifaces) do
        table.insert(items, {
            title    = "    Interfaz: " .. iface.interface,
            disabled = true,
        })
        if iface.ip then
            table.insert(items, {
                title    = "    IP del túnel: " .. iface.ip,
                disabled = true,
            })
        end
    end

    -- Información geográfica del túnel (si disponible)
    local info = cache.data
    if info then
        table.insert(items, { title = "-" })
        table.insert(items, { title = "🌍  IP pública via VPN", disabled = true })
        table.insert(items, { title = "    IP: "       .. (info.query      or "?"), disabled = true })
        table.insert(items, { title = "    País: "     .. (info.country    or "?"), disabled = true })
        table.insert(items, { title = "    Región: "   .. (info.regionName or "?"), disabled = true })
        table.insert(items, { title = "    Ciudad: "   .. (info.city       or "?"), disabled = true })
        table.insert(items, { title = "    ISP: "      .. (info.isp        or "?"), disabled = true })
        table.insert(items, { title = "    Operador: " .. (info.org        or "?"), disabled = true })
    else
        table.insert(items, { title = "-" })
        table.insert(items, { title = "    Obteniendo información…", disabled = true })
    end

    -- Refrescar
    table.insert(items, { title = "-" })
    table.insert(items, {
        title = "Actualizar",
        fn    = function()
            cache.data = nil
            M.refresh(on_update)
            if on_update then on_update() end
        end,
    })

    return items
end

return M
