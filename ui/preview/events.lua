---@class ui.preview.events.hub
local hub = {}
hub.__index = hub
hub.__name = 'hub'
---@type fun(canvas: hs.canvas, eventType: string, elementId: any, x: number, y: number)
hub.cbForMouseEvents = nil
---@type hs.logger
hub.log = nil

---@return ui.preview.events.hub
function hub:new(tag, loglevel)
    local o = {}

    o.log = hs.logger.new(tag or 'ui.preview.events.hub', loglevel or 'info')
    o.cbForMouseEvents = function(canvas, eventType, elementId, x, y)
        o:dispatch(elementId)(eventType, x, y)
    end

    setmetatable(o, self)
    return o
end

function hub:dispatch(elementId)
    if self:handlers()[elementId] == nil then
        self.log.wf('No handler for elementId: %s', elementId)
        return function(_, _, _) end
    else
        return function(eventType, x, y)
            if #self:handlers()[elementId] == 0 then
                self.log.wf('Empty handler set for elementId: %s', elementId)
            end
            hs.fnutils.each(self:handlers()[elementId], function(handler)
                self.log.df('processing event <elementId: %s, eventType: %s', elementId, eventType)
                handler(eventType, x, y)
            end)
        end
    end
end

---@return table<string, fun(event_type:string, x:number, y:number)[]>>
function hub:handlers()
    if self.__handlers == nil then
        self.__handlers = {}
    end
    return self.__handlers
end

---@class ui.preview.events.watcher
local watcher = {}
watcher.__index = watcher
watcher.__name = 'watcher'

---@param elementIds string[]
---@return ui.preview.events.watcher
function hub:attach(elementIds)
    local o = {}
    o.elementId = elementId
    o.ctx = {}
    o.config = {
        tapTimeout = 0.2,
        longTapTimeout = 0.7,
    }

    setmetatable(o, watcher)
    o:hooks({
        onSessionBegin = function() end,
        onSessionEnd = function() end,
        onTap = function() end,
        onLongTap = function() end,
        onClick = function() end,
        onDoubleClick = function() end,
        onDrag = function() end,
        onMoveBegin = function() end,
        onMoveEnd = function() end,
    })
    o:actionMap({
        mouseEnter = function(x, y) end,
        mouseExit = function(x, y) end,
        mouseMouseUp = function(x, y) end,
        mouseDown = function(x, y) end,
    })
    hs.fnutils.each(elementIds, function(elementId)
        if self:handlers()[elementId] == nil then
            self:handlers()[elementId] = {}
        end
        table.insert(self:handlers()[elementId], function(eventType, x, y) return o:onMouse(eventType, x, y) end)
    end)
    o:idle()

    return o
end



---@param newActionMap { [string]: fun(x: integer, y: integer) }
---@return { [string]: fun(x: integer, y: integer) }
function watcher:actionMap(newActionMap)
    if newActionMap ~= nil then
        self.__actionMap = newActionMap
    end
    if self.__actionMap == nil then
        self.__actionMap = {}
    end
    return self.__actionMap
end

---@param { [string]: fun() }
function watcher:hook(name, fn)
    if self.__hooks == nil then
        self.__hooks = {}
    end
    self.__hooks[name] = fn
    return self
end

---@param h { [string]: fun() }
---@return { [string]: fun() }
function watcher:hooks(h)
    if h ~= nil then
        self.__hooks = h
        return self
    end
    if self.__hooks == nil then
        self.__hooks = {}
    end
    return self.__hooks
end

function watcher:start()
    --self:resume()
    return self
end

function watcher:stop()
    --self:reset()
    --self:idle()
    --self:pause()
    return self
end

function watcher:reset()
    self.ctx = {}
    self:actionMap({
        mouseEnter = function(x, y) self:reset() end,
        mouseExit = function(x, y) self:reset() end,
        mouseMouseUp = function(x, y) self:reset() end,
        mouseDown = function(x, y) self:reset() end,
    })
    return self
end

function watcher:idle()
    self:reset()
    self:actionMap().mouseEnter = function(x, y)
        self.ctx.status = 'idle'
        self.ctx.x = x
        self.ctx.y = y
        self.ctx.timer = hs.timer.doAfter(self.config.tapTimeout, function()
            self.ctx.status = 'tap'
            self:hooks().onTap()
            self.ctx.timer = hs.timer.doAfter(self.config.longTapTimeout, function()
                self.ctx.status = 'longTap'
                self:hooks().onLongTap()
            end)
        end)

        self:actionMap().mouseDown = function(_, _)
            self:actionMap().mouseDown = function(_, _) end
            self:actionMap().mouseUp = function(_, _)
                self.ctx.status = 'click'
                self:hooks().onClick()
            end
        end

        self:hooks().onSessionBegin()
        self:actionMap().mouseExit = function(_, _)
            self:hooks().onSessionEnd()
        end
    end

    return self
end

function watcher:onMouse(eventType, x, y)
    if self:actionMap()[eventType] == nil then  return end
    self:actionMap()[eventType](x, y)
end

return hub
