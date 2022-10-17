ui = {
    frame = require('ui.frame'),
    preview = {
        events = require('ui.preview.events'),
        state = require('ui.preview.state'),
        window = require('ui.preview.window')
    },
    control = {
        viewLink = require('ui.control.viewLink'),
        watcher = require('ui.control.watcher')
    }
}
hs.window.animationDuration = 0.5

---@class UI
UI = {}
UI.__index = UI
UI.__name = 'UI'
---@type hs.canvas
UI.bg = nil
---@type ui.preview.window[]
UI.previews = nil

---@return UI
function UI:new()
    local o = {}
    setmetatable(o, self)
    return o:init()
end

function UI:init()
    local log = hs.logger.new('ui.main', 'warning')
    local display = hs.screen.mainScreen():frame()
    local fullDisplay = hs.screen.mainScreen():fullFrame()
    local offset = (fullDisplay.h - display.h) / fullDisplay.h
    local capacity = { 1, 2, 3, 4, 5, 6, 7, 8}
    local workspaceRect = ui.frame:fractions(0.15, offset, 0.85, 1-offset)
    local previewSpaceRect = ui.frame:fractions(0.0, 0, 0.15, 1)
    local previewRect = hs.fnutils.map(capacity, function(i)
        return ui.frame:fractions(0, offset + (i-1)/#capacity, 0.15, 1/#capacity)
    end)
    self.previews = hs.fnutils.map(previewRect, function(rect)
        return ui.preview.window:new(rect)
    end)

    self.bg = hs.canvas.new(previewSpaceRect:rect()):appendElements({
        --type = "image",
        --action = "fill",
        --image = hs.image.imageFromPath(hs.configdir .. "/bg.png"),
        --imageScaling = "scaleToFit",
        --imageAlpha = 0.8,
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
    :level(hs.canvas.windowLevels.floating)
    :wantsLayer(true)
    self.controller = ui.control.watcher:new(self.previews)

    return self
end


function UI:start()
    self.bg:show()
    hs.fnutils.each(self.previews, function(p) p:show() end)
    self.controller:start()
    return self
end

return UI
