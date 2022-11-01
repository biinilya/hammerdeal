---@diagnostic disable-next-line lowercase-global
ui = {}
ui.__index = ui

ui.name = "ui"
ui.version = "0.1"
ui.author = "http://github.com/biinilya"
ui.license = "MIT - https://opensource.org/licenses/MIT"
ui.boolMap = {
    [""] = false,
    [{}] = false,
    [0] = false,
}

ui.fn = hs.fnutils
ui.screen = hs.screen.mainScreen():fullFrame()
ui.desktop = hs.screen.mainScreen():frame()
ui.config = require('ui.config')
ui.control = require('ui.control')
ui.preview = require('ui.preview')
ui.state = require('ui.preview.state')
ui.events = require('ui.preview.events')
ui.channel = require('ui.preview.channel')
ui.exchange = require('ui.preview.exchange')
ui.main = require('ui.main')
ui.init = ui

hs.window.animationDuration = 0
hs.screen.watcher.newWithActiveScreen(function ()
    ui.screen = hs.screen.mainScreen():fullFrame()
    ui.desktop = hs.screen.mainScreen():frame()
end)

---@generic T
---@return boolean
function ui.bool(v)
    if ui.boolMap[v] ~= nil then
        return ui.boolMap[v]
    elseif v then
        return true
    else
        return false
    end
end

---@generic T
---@param list T[]
---@param filter fun(value: T): boolean
---@return T
function ui.ifilter(list, filter)
    local result = {}
    for _, v in ipairs(list) do
        if filter(v) then
            table.insert(result, v)
        end
    end
    return result
end

---@generic T
---@param ref T
---@return fun(value: T): boolean
function ui.eq(ref)
    return function (value)
        return value == ref
    end
end

---@generic T
---@param ref T
---@return fun(value: T): boolean
function ui.startsWith(ref)
    return function(value)
        return string.sub(value, 1, #ref) == ref
    end
end


---@generic T
---@param ref T
---@return fun(value: T): boolean
function ui.ne(ref)
    return function (value)
        return value ~= ref
    end
end

---@generic T
---@return T
function ui.partial(fn, ...)
    return hs.fnutils.partial(fn, ...)
end


return ui
