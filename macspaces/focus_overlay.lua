-- macspaces/focus_overlay.lua
-- Banner flotante persistente que muestra el estado de enfoque activo.
-- Usa hs.canvas para un overlay semi-transparente en esquina superior derecha.

local M = {}

local pomodoro     = require("macspaces.pomodoro")
local breaks       = require("macspaces.breaks")
local presentation = require("macspaces.presentation")
local utils        = require("macspaces.utils")

local canvas = nil
local timer  = nil

local PADDING_X = 10
local PADDING_Y = 6
local MARGIN    = 8   -- margen desde el borde de pantalla
local TOP_OFFSET = 30 -- debajo de la menubar
local FONT_SIZE = 14
local BG_ALPHA  = 0.75
local CORNER_R  = 8

-- ─────────────────────────────────────────────
-- Determinar qué mostrar
-- ─────────────────────────────────────────────

local function get_label()
    if pomodoro.is_active() then
        return pomodoro.time_label()
    end
    if presentation.is_active() then
        return "🎬 Presentación"
    end
    -- Descanso activo no tiene countdown, no justifica overlay permanente
    return nil
end

-- ─────────────────────────────────────────────
-- Canvas
-- ─────────────────────────────────────────────

local function destroy_canvas()
    if canvas then canvas:delete(); canvas = nil end
end

local function create_canvas(label)
    destroy_canvas()

    -- Medir texto para dimensionar el canvas
    local text_style = {
        font = { name = ".AppleSystemUIFont", size = FONT_SIZE },
        color = { white = 1, alpha = 1 },
    }
    local styled = hs.styledtext.new(label, text_style)
    local size = hs.drawing.getTextDrawingSize(styled)
    local w = size.w + PADDING_X * 2
    local h = size.h + PADDING_Y * 2

    -- Posicionar en esquina superior derecha
    local screen = hs.screen.mainScreen():frame()
    local x = screen.x + screen.w - w - MARGIN
    local y = screen.y + TOP_OFFSET

    canvas = hs.canvas.new({ x = x, y = y, w = w, h = h })
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    canvas:level(hs.canvas.windowLevels.floating)
    canvas:clickActivating(false)
    canvas:mouseCallback(nil)

    -- Fondo
    canvas[1] = {
        type             = "rectangle",
        fillColor        = { white = 0, alpha = BG_ALPHA },
        strokeColor      = { white = 0.3, alpha = 0.5 },
        strokeWidth      = 0.5,
        roundedRectRadii = { xRadius = CORNER_R, yRadius = CORNER_R },
        action           = "strokeAndFill",
    }

    -- Texto
    canvas[2] = {
        type = "text",
        text = styled,
        frame = { x = PADDING_X, y = PADDING_Y, w = size.w, h = size.h },
    }

    canvas:show()
end

-- ─────────────────────────────────────────────
-- Actualización
-- ─────────────────────────────────────────────

local function update()
    local label = get_label()
    if label then
        create_canvas(label)
    else
        destroy_canvas()
    end
end

-- ─────────────────────────────────────────────
-- API pública
-- ─────────────────────────────────────────────

function M.start()
    update()
    -- Actualizar cada segundo (para countdown del Pomodoro)
    if not timer then
        timer = hs.timer.doEvery(1, update)
    end
end

function M.stop()
    if timer then timer:stop(); timer = nil end
    destroy_canvas()
end

function M.refresh()
    update()
end

return M
