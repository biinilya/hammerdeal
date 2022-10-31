---@class UI
UI = {}
UI.__index = UI
UI.__name = 'UI'
---@type hs.canvas
UI.bg = nil
---@type ui.preview.window[]
UI.previews = nil
UI.controller = nil

---@return UI
function UI:new()
    local o = {}
    setmetatable(o, self)
    return o:init()
end

function UI:init()
    local log = hs.logger.new('ui.main', 'warning')
    local display = hs.screen.mainScreen():frame()
    local offset = (fullDisplay.h - display.h) / fullDisplay.h
    local capacity = { 1, 2, 3, 4, 5, 6, 7, 8}
    local previewSpaceRect = ui.frame:fractions(0.0, 0, 0.15, 1)
    local previewRect = hs.fnutils.map(capacity, function(i)
        return pw:new(
            f:fractions(0, offset + (i - 1) / #capacity, 0.15, 1 / #capacity):rect()
        )
    end)

    self.bg = hs.canvas.new(previewSpaceRect:rect())
    self.bg:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = { white = 0.1, alpha = 0.7 },
        frame = { x = "0%", y = "0%", h = "100%", w = "100%" },
        padding = 0,
        fillGradient = "radial",
        fillGradientAngle = 45,
        fillGradientColors = {
            { white = 0.1, alpha = 0.8 },
            { white = 0.9, alpha = 0.8 },
            { white = 0.1, alpha = 0.4 },
            { white = 0.9, alpha = 0.8 },
            { white = 0.1, alpha = 0.8 },
        },
        fillGradientCenter = { x = -1.0, y = -1.0 },
        compositeRule = 'sourceOver',
    })
    self.bg:show()
    self.controller = c:new():start(previewRect)

    return self
end


function UI:start()
    return self
end

return UI
