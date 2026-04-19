local M = {}

local CACHE_FILE = os.getenv("HOME") .. "/.gemini/usage_cache.json"
local CACHE_MAX_AGE = 6 * 3600 -- 6 horas
local STALE_THRESHOLD = 10 * 60 -- 10 minutos

local MODEL_DISPLAY = {
    ["gemini-2.5-flash"]              = "flash",
    ["gemini-2.5-flash-lite"]         = "flash-lite",
    ["gemini-2.5-pro"]                = "pro",
    ["gemini-3-pro-preview"]          = "3-pro",
    ["gemini-3-flash-preview"]        = "3-flash",
    ["gemini-3.1-pro-preview"]        = "3.1-pro",
    ["gemini-3.1-flash-lite-preview"] = "3.1-flash-lite",
}

local cache_data = nil
local last_load = 0

function M.fetch()
    local now = os.time()
    if cache_data and (now - last_load) < 60 then
        return cache_data
    end

    local f = io.open(CACHE_FILE, "r")
    if not f then
        cache_data = { models = {}, updated_at = 0, source = "none" }
        return cache_data
    end

    local content = f:read("*all")
    f:close()

    local status, data = pcall(hs.json.decode, content)
    if status and data then
        cache_data = data
        cache_data.source = "cache"
        last_load = now
    else
        cache_data = { models = {}, updated_at = 0, source = "none" }
    end

    return cache_data
end

function M.invalidate()
    cache_data = nil
    last_load = 0
end

function M.has_session()
    local data = M.fetch()
    return data.source == "cache" and data.updated_at > 0 and (os.time() - data.updated_at) < CACHE_MAX_AGE
end

function M.color_for(pct)
    if pct >= 85 then
        return { red = 0.85, green = 0.20, blue = 0.15, alpha = 0.85 }
    elseif pct >= 60 then
        return { red = 0.90, green = 0.65, blue = 0.10, alpha = 0.85 }
    else
        return { red = 0.15, green = 0.50, blue = 0.30, alpha = 0.85 }
    end
end

local function get_bar(pct)
    local len = 8
    local filled = math.floor((pct / 100) * len)
    local s = "▰"
    local e = "▱"
    local bar = ""
    for i = 1, len do
        bar = bar .. (i <= filled and s or e)
    end
    return bar
end

local function freshness_indicator(updated_at)
    local diff = os.time() - updated_at
    if diff > STALE_THRESHOLD then
        return "  [⏸ " .. math.floor(diff / 60) .. "m]"
    end
    return "  [▶]"
end

function M.overlay_rows(minimal)
    local data = M.fetch()
    local rows = {}
    for _, model in ipairs(data.models) do
        local display = MODEL_DISPLAY[model.model_id] or model.model_id:match("([^%-]+)$") or model.model_id
        local bar = get_bar(model.pct)
        local freshness = freshness_indicator(data.updated_at)
        local reset = os.date("%H:%M", model.reset)
        
        local label
        if minimal then
            label = string.format("✦ Gemini %s  %d%%%s  ↺%s", display, model.pct, freshness, reset)
        else
            label = string.format("✦ Gemini %s  %s  %d%%%s  ↺%s", display, bar, model.pct, freshness, reset)
        end
        table.insert(rows, { label = label, pct = model.pct })
    end
    return rows
end

function M.overlay_label()
    local data = M.fetch()
    if #data.models > 0 then
        return "✦ Gemini " .. (MODEL_DISPLAY[data.models[1].model_id] or "active")
    end
    return "✦ Gemini"
end

function M.build_submenu()
    local data = M.fetch()
    local menu = {}

    if data.source == "none" then
        table.insert(menu, { title = "Sin datos de Gemini CLI" })
        table.insert(menu, { title = "Abrir AI Studio", fn = function() hs.urlevent.openURL("https://aistudio.google.com/") end })
        return menu
    end

    for _, model in ipairs(data.models) do
        table.insert(menu, { title = string.format("%s: %d%%", MODEL_DISPLAY[model.model_id] or model.model_id, model.pct) })
        table.insert(menu, { title = "  Reset: " .. os.date("%Y-%m-%d %H:%M", model.reset) })
    end

    if #menu > 0 then table.insert(menu, { title = "-" }) end

    local diff = os.time() - data.updated_at
    if data.updated_at > 0 and diff > STALE_THRESHOLD then
        table.insert(menu, { title = "⏸ Dato desactualizado — hace " .. math.floor(diff / 60) .. "m" })
        table.insert(menu, { title = "-" })
    end

    table.insert(menu, { title = "Abrir uso detallado", fn = function() hs.urlevent.openURL("https://aistudio.google.com/") end })
    table.insert(menu, { title = "Actualizar", fn = function() M.invalidate() end })

    return menu
end

return M
