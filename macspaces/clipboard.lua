-- macspaces/clipboard.lua
-- Historial del portapapeles: almacena hasta N entradas recientes.
-- Al seleccionar una entrada, la restaura al portapapeles para pegado manual.

local M = {}

local cfg   = require("macspaces.config")
local utils = require("macspaces.utils")

-- ─────────────────────────────────────────────
-- Estado interno
-- ─────────────────────────────────────────────
local history    = {}   -- tabla de entradas { type, content, label, timestamp }
local watcher    = nil
local last_change = hs.pasteboard.changeCount()

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function truncate(str, max)
    if not str then return "" end
    str = str:gsub("[\n\r\t]", " "):gsub("%s+", " ")
    if #str > max then
        return str:sub(1, max) .. "…"
    end
    return str
end

local function capture_entry()
    local types = hs.pasteboard.contentTypes()
    if not types or #types == 0 then return end

    local entry = { timestamp = os.time() }

    -- Texto
    local text = hs.pasteboard.getContents()
    if text and text ~= "" then
        entry.type    = "text"
        entry.content = text
        entry.label   = truncate(text, 60)

    -- Imagen
    elseif hs.pasteboard.readImage() then
        local img = hs.pasteboard.readImage()
        entry.type    = "image"
        entry.content = img
        entry.label   = "[Imagen]"

    -- Archivo(s)
    elseif hs.pasteboard.readURL() then
        local url = hs.pasteboard.readURL()
        entry.type    = "url"
        entry.content = url
        entry.label   = truncate(url, 60)

    else
        -- Tipo no soportado para preview
        entry.type    = "other"
        entry.content = nil
        entry.label   = "[Contenido no previsualizable]"
    end

    -- Evitar duplicados consecutivos
    if #history > 0 and history[1].label == entry.label then return end

    table.insert(history, 1, entry)

    -- Limitar al máximo configurado
    local max = cfg.clipboard and cfg.clipboard.max_entries or 20
    while #history > max do
        table.remove(history)
    end

    utils.log("[INFO] Clipboard: entrada capturada (" .. entry.type .. ")")
end

-- ─────────────────────────────────────────────
-- API pública
-- ─────────────────────────────────────────────

function M.start(on_change)
    watcher = hs.timer.doEvery(1, function()
        local count = hs.pasteboard.changeCount()
        if count ~= last_change then
            last_change = count
            capture_entry()
            if on_change then on_change() end
        end
    end)
    utils.log("[INFO] Clipboard watcher iniciado")
end

function M.stop()
    if watcher then
        watcher:stop()
        watcher = nil
    end
end

function M.clear()
    history = {}
    utils.log("[INFO] Clipboard: historial limpiado")
end

function M.restore(index)
    local entry = history[index]
    if not entry then return end

    if entry.type == "text" then
        hs.pasteboard.setContents(entry.content)
    elseif entry.type == "image" and entry.content then
        hs.pasteboard.writeObjects(entry.content)
    elseif entry.type == "url" then
        hs.pasteboard.setContents(entry.content)
    end

    utils.log("[OK] Clipboard: entrada " .. index .. " restaurada")
end

-- Construye el submenú del portapapeles
function M.build_submenu(on_update)
    local items = {}
    local max   = cfg.clipboard and cfg.clipboard.max_entries or 20

    -- Encabezado con contador
    table.insert(items, {
        title = string.format("Historial  %d/%d", #history, max),
        fn    = function() end,
    })
    table.insert(items, { title = "-" })

    if #history == 0 then
        table.insert(items, { title = "Sin entradas aún", fn = function() end })
        return items
    end

    -- Búsqueda: abre un diálogo de texto y filtra el historial
    table.insert(items, {
        title = "🔍  Buscar…",
        fn    = function()
            local ok, query = hs.dialog.textPrompt("Buscar en portapapeles", "Escribe para filtrar:", "", "Buscar", "Cancelar")
            if not ok or query == "" then return end

            local q = query:lower()
            local results = {}
            for _, entry in ipairs(history) do
                if entry.label:lower():find(q, 1, true) then
                    table.insert(results, entry)
                end
            end

            if #results == 0 then
                hs.dialog.blockAlert("Sin resultados", "No se encontraron entradas para: " .. query, "OK")
            else
                -- Mostrar resultados en un chooser (selector visual)
                local choices = {}
                for i, entry in ipairs(results) do
                    local icon_map = { text = "📝", image = "🖼", url = "🔗", other = "📋" }
                    table.insert(choices, {
                        text    = entry.label,
                        subText = os.date("%H:%M", entry.timestamp) .. "  ·  " .. (entry.type or ""),
                        image   = hs.image.imageFromName(icon_map[entry.type] or "📋"),
                        _entry  = entry,
                        _index  = i,
                    })
                end

                local chooser = hs.chooser.new(function(choice)
                    if not choice then return end
                    -- Encontrar índice real en history
                    for idx, e in ipairs(history) do
                        if e == choice._entry then
                            M.restore(idx)
                            utils.notify("macSpaces", "Portapapeles restaurado")
                            break
                        end
                    end
                end)
                chooser:choices(choices)
                chooser:placeholderText("Resultados para: " .. query)
                chooser:show()
            end
        end,
    })

    table.insert(items, { title = "-" })

    -- Entradas del historial
    for i, entry in ipairs(history) do
        local time_label = os.date("%H:%M", entry.timestamp)
        local icon = ({ text = "📝", image = "🖼", url = "🔗", other = "📋" })[entry.type] or "📋"

        table.insert(items, {
            title = string.format("%s  %s  [%s]", icon, entry.label, time_label),
            fn    = function()
                M.restore(i)
                utils.notify("macSpaces", "Portapapeles restaurado")
            end,
        })
    end

    table.insert(items, { title = "-" })
    table.insert(items, {
        title = "Limpiar historial",
        fn    = function()
            M.clear()
            if on_update then on_update() end
        end,
    })

    return items
end

return M
