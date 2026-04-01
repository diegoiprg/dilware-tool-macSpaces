-- macspaces/focus_overlay.lua
-- Banner flotante persistente que muestra el estado de enfoque activo.
-- Muestra: Pomodoro countdown, presentación, o tiempo sin descanso.

local M = {}

local pomodoro     = require("macspaces.pomodoro")
local breaks       = require("macspaces.breaks")
local presentation = require("macspaces.presentation")

local canvas = nil
local timer  = nil

local PADDING_X  = 10
local PADDING_Y  = 6
local MARGIN     = 8
local TOP_OFFSET = 30
local FONT_SIZE  = 14
local BG_ALPHA   = 0.75
local CORNER_R   = 8

local function get_label()
    if pomodoro.is_active() then
        return pomodoro.time_label()
    end
    if presentation.is_active() then
        return "🎬 Presentación"
    end
    -- Mostrar tiempo sin descanso si es significativo (> 5 min)
    return breaks.idle_label()
end

local function destroy_canvas()
    if canvas then canvas:delete(); canvas = nil end
end

local function create_canvas(label)
    destroy_canvas()

    local text_style = {
        font = { name = ".AppleSystemUIFont", size = FONT_SIZE },
        color = { white = 1, alpha = 1 },
    }
    local styled = hs.styledtext.new(label, text_style)
    local size = hs.drawing.getTextDrawingSize(styled)
    local w = size.w + PADDING_X * 2
    local h = size.h + PADDING_Y * 2

    local screen = hs.screen.mainScreen():frame()
    local x = screen.x + screen.w - w - MARGIN
    local y = screen.y + TOP_OFFSET

    canvas = hs.canvas.new({ x = x, y = y, w = w, h = h })
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    canvas:level(hs.canvas.windowLevels.floating)
    canvas:clickActivating(false)

    canvas[1] = {
        type             = "rectangle",
        fillColor        = { white = 0, alpha = BG_ALPHA },
        strokeColor      = { white = 0.3, alpha = 0.5 },
        strokeWidth      = 0.5,
        roundedRectRadii = { xRadius = CORNER_R, yRadius = CORNER_R },
        action           = "strokeAndFill",
    }

    canvas[2] = {
        type  = "text",
        text  = styled,
        frame = { x = PADDING_X, y = PADDING_Y, w = size.w, h = size.h },
    }

    canvas:show()
end

local function update()
    local label = get_label()
    if label then
        create_canvas(label)
    else
        destroy_canvas()
    end
end

function M.start()
    update()
    if not timer then timer = hs.timer.doEvery(1, update) end
end

function M.stop()
    if timer then timer:stop(); timer = nil end
    destroy_canvas()
end

function M.refresh() update() end

return M
