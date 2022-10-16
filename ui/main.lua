ui = {preview={}, control={}}
ui.frame = require('ui.frame')
ui.preview.events = require('ui.preview.events')
ui.preview.state = require('ui.preview.state')
ui.preview.window = require('ui.preview.window')
ui.control.viewLink = require('ui.control.viewLink')
ui.control.watcher = require('ui.control.watcher')

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
    local log = hs.logger.new('ui.main', 'info')
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
        return ui.preview.window:new(rect, workspaceRect)
    end)

    self.bg = hs.canvas.new(previewSpaceRect:rect()):appendElements({
        type = "image",
        action = "fill",
        image = hs.image.imageFromPath(hs.configdir .. "/bg.png"),
        imageScaling = "scaleToFit",
        imageAlpha = 0.5,
        compositeRule = 'plusDarker',
    }):level(hs.canvas.windowLevels.desktopIcon)
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
