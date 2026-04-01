-- macspaces/vpn.lua
-- Detección de VPN activa: interfaces utun*/ppp*, IP del túnel,
-- información geográfica via ipapi.co (HTTPS gratuito).

local M = {}

local utils = require("macspaces.utils")

-- ─────────────────────────────────────────────
-- Detección de interfaces VPN
-- ─────────────────────────────────────────────

local function detect_vpn_interfaces()
    local vpn_ifaces = {}
    local ifaces = hs.network.interfaces()
    if not ifaces then return vpn_ifaces end

    for _, iface in ipairs(ifaces) do
        if iface:match("^utun") or iface:match("^ppp") then
            local details = hs.network.interfaceDetails(iface)
            if details and details["IPv4"] then
                local addrs = details["IPv4"]["Addresses"]
                local ip = (addrs and #addrs > 0) and addrs[1] or nil

                local is_system = false
                if ip then
                    if ip:match("^169%.254%.") then is_system = true end
                    local a, b = ip:match("^(%d+)%.(%d+)%.")
                    if a == "100" and tonumber(b) >= 64 and tonumber(b) <= 127 then
                        is_system = true
                    end
                end

                if not is_system then
                    table.insert(vpn_ifaces, { interface = iface, ip = ip })
                end
            end
        end
    end

    return vpn_ifaces
end

-- ─────────────────────────────────────────────
-- Caché unificado: interfaces + info remota
-- ─────────────────────────────────────────────

local cache = {
    ifaces       = nil,
    ifaces_fetch = 0,
    ifaces_ttl   = 10,
    data         = nil,
    fetching     = false,
    last_ip      = nil,
    last_fetch   = 0,
    ttl          = 120,
}

-- Devuelve interfaces desde caché (evita llamar detect_vpn_interfaces múltiples veces)
local function cached_interfaces()
    local now = os.time()
    if cache.ifaces and (now - cache.ifaces_fetch) < cache.ifaces_ttl then
        return cache.ifaces
    end
    cache.ifaces = detect_vpn_interfaces()
    cache.ifaces_fetch = now
    return cache.ifaces
end

local function normalize_response(data)
    return {
        query       = data.ip,
        country     = data.country_name,
        countryCode = data.country_code,
        regionName  = data.region,
        city        = data.city,
        isp         = data.org or "?",
        org         = data.org or "?",
    }
end

local function fetch_tunnel_info(tunnel_ip, on_done)
    if cache.fetching then return end
    if not tunnel_ip or tunnel_ip == "" then
        if on_done then on_done() end
        return
    end

    local now = os.time()
    if cache.data and cache.last_ip == tunnel_ip and (now - cache.last_fetch) < cache.ttl then
        if on_done then on_done() end
        return
    end

    cache.fetching = true

    local url = "https://ipapi.co/" .. tunnel_ip .. "/json/"

    hs.http.asyncGet(url, nil, function(status, body, _)
        cache.fetching = false
        if status == 200 and body then
            local ok, data = pcall(function() return hs.json.decode(body) end)
            if ok and data and data.ip then
                cache.data       = normalize_response(data)
                cache.last_ip    = tunnel_ip
                cache.last_fetch = os.time()
            end
        end
        if on_done then on_done() end
    end)
end

-- ─────────────────────────────────────────────
-- API pública
-- ─────────────────────────────────────────────

function M.is_active()
    return #cached_interfaces() > 0
end

function M.interfaces()
    return cached_interfaces()
end

function M.refresh(on_done)
    cache.ifaces = nil; cache.ifaces_fetch = 0  -- invalidar
    local ifaces = cached_interfaces()
    if #ifaces > 0 and ifaces[1].ip then
        fetch_tunnel_info(ifaces[1].ip, on_done)
    else
        cache.data = nil
        if on_done then on_done() end
    end
end

function M.build_submenu(on_update)
    local ifaces = cached_interfaces()  -- usa caché, no recalcula
    local items  = {}

    if #ifaces == 0 then
        table.insert(items, utils.disabled_item("🔓  Sin VPN activa"))
        return items
    end

    table.insert(items, utils.disabled_item(
        "🔒  VPN activa (" .. #ifaces .. " interfaz" .. (#ifaces > 1 and "es" or "") .. ")"
    ))
    table.insert(items, { title = "-" })

    for _, iface in ipairs(ifaces) do
        table.insert(items, utils.info_item("Interfaz: ", iface.interface))
        if iface.ip then
            table.insert(items, utils.info_item("IP del túnel: ", iface.ip))
        end
    end

    local info = cache.data
    if info then
        table.insert(items, { title = "-" })
        table.insert(items, utils.disabled_item("🌍  IP pública via VPN"))
        table.insert(items, utils.info_item("IP: ",       info.query      or "?"))
        table.insert(items, utils.info_item("País: ",     info.country    or "?"))
        table.insert(items, utils.info_item("Región: ",   info.regionName or "?"))
        table.insert(items, utils.info_item("Ciudad: ",   info.city       or "?"))
        table.insert(items, utils.info_item("ISP: ",      info.isp        or "?"))
    else
        table.insert(items, { title = "-" })
        table.insert(items, utils.disabled_item("Obteniendo información…"))
    end

    table.insert(items, { title = "-" })
    table.insert(items, {
        title = "Actualizar",
        fn    = function()
            cache.data = nil; cache.ifaces = nil; cache.ifaces_fetch = 0
            M.refresh(on_update)
        end,
    })

    return items
end

return M
