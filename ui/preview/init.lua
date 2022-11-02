local M = {}
M.__index = M

M.name = "ui.preview"
M.version = "0.1"
M.author = "http://github.com/biinilya"
M.license = "MIT - https://opensource.org/licenses/MIT"

M.channel = require('ui.preview.channel')
M.exchange = require('ui.preview.exchange')
M.events = require('ui.preview.events')
M.state = require('ui.preview.state')
M.window = require('ui.preview.window')
M.init = M
M.size = hs.geometry({ w = 276, h = 200 })

---@param bundleID string
---@return hs.image
M.thumbnail = function(bundleID)
    local _c = hs.canvas.new(
        { w = 276, h = 200 }
    )
    --_c[1] = {
    --    type = "rectangle",
    --    action = "stroke",
    --    fillGradientColors = { {
    --        hex = "#37474F",
    --        alpha = 0.7
    --    }, {
    --        hex = "#263238",
    --        alpha = 0.6
    --    } },
    --    fillGradient = "radial"
    --}
    return (_c):imageFromCanvas()
end

M.thumbnailS = function(bundleID)
    local _c = hs.canvas.new(
        hs.screen.mainScreen():frame():scale(0.125)
    )
    --_c[1] = {
    --    type = "rectangle",
    --    action = "stroke",
    --    fillGradientColors = { {
    --        hex = "#37474F",
    --        alpha = 0.7
    --    }, {
    --        hex = "#263238",
    --        alpha = 0.6
    --    } },
    --    fillGradient = "radial"
    --}
    return (_c):imageFromCanvas()
end

M.logo = function(bundleID)
    return hs.image.imageFromAppBundle(bundleID)
end


return M
