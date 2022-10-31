---@class action
---@field triggered boolean
local action = {}
action.__index = action
action.__name = 'action'

function action.new()
    local o = {
        triggered = false
    }
    setmetatable(o, action)
    return o
end

function action:doOnce(actor)
    if self.triggered then
        return
    end
    self.triggered = true
    actor()
end

---@class stateController
---@field elements table<string, hs.watchable>
---@field before hs.watchable
---@field latest hs.watchable
---@field focused hs.watchable
---@field selected hs.watchable
---@field beingDragged hs.watchable
---@field selectionLostTimer hs.timer.delayed
---@field draggingTimer hs.timer.delayed
local canvasController = {}
canvasController.__index = canvasController
canvasController.__name = 'stateController'

local function repr(...)
    return hs.inspect.inspect({ ... }, { newline = '', indent = '' })
end

---@param hub ui.preview.events.hub
function canvasController.new(pathMask)
    local o = {}
    setmetatable(o, canvasController)

    o.elements = {}
    o.elementsPrivate = {}
    o.pathMask = pathMask
    o.selectionLostTimer = hs.timer.delayed.new(2, function() o:onSelectionLost() end)
    o.draggingTimer = nil
    return o
end

---@param canvas hs.canvas
---@param eventType string
---@param elementId string
---@param x number
---@param y number
function canvasController:onMouseEvent(canvas, eventType, elementId, x, y)
    local state = self.elements[elementId]
    if state == nil then
        self.elementsPrivate[elementId] = self.elementsPrivate[elementId] or {}
        self.elementsPrivate[elementId].listenForFocusUpdates = hs.watchable.watch(
            string.format(self.pathMask, elementId), 'isFocused',
            function(watcher, path, key, old, new)
                if new == true then
                    for element, state in pairs(self.elements) do
                        if element ~= elementId then
                            self.elements[element].isFocused = false
                        end
                    end
                end
            end
        )
        state = hs.watchable.new(string.format(self.pathMask, elementId), true)
        state.id = elementId
        state.canvas = canvas
        state.isFocused = false
        state.isLocked = false
        state.isSelected = false
        state.isDragged = false
        state.actionRequested = nil
        state.cursorLocation = nil
        state.dropTarget = nil
        state.latestEvents = {}
        self.elements[elementId] = state
    end

    self.before = self.latest
    self.latest = state
    state.latestEvents[eventType] = { hs.timer.absoluteTime(), canvas, elementId, x, y }

    --- cursor management
    state.cursorLocation = { x, y }
    if self.before ~= nil and  state.id ~= self.before.id then
        self.before.cursorLocation = nil
    end

    --- selection management
    if eventType ~= 'mouseExit' then
        self:ensureFocused(state)
    end


    --- selection management
    if eventType ~= 'mouseExit' then
        self:ensureFocused(state)
    end

    --- drag management
    if eventType == 'mouseDown' then
        self.draggingTimer = hs.timer.delayed.new(2, function() self:onDraggingStart(state) end):start()
    end
    if eventType == 'mouseUp' then
        self:onDraggingCancel()
    end


    return self._state
end


function canvasController:ensureFocused(who)
    who.isSelected = true
    if self.selected ~= nil and self.selected.id ~= who.id then
        self:onSelectionLost()
    end
    self.selected = who
    self.selectionLostTimer:start()
end

function canvasController:onSelectionLost()
    if self.selected ~= nil then
        self.selected.isSelected = false
    end
    self.selected = nil
end

function canvasController:onDraggingCancel()
    self.draggingTimer:stop()
    if hs.timer.absoluteTime() - self.latest.latestEvents['mouseDown'][1] < 0.5*1e9 then
        self.latest.actionRequested = action.new()
        return
    end
end

function canvasController:onDraggingStart(who)
    self.beingDragged = who
    who.isDragged = true
    who.refreshCursorPosition = hs.timer.doEvery(0.05, function()
        local loc = hs.mouse.getRelativePosition()
        who.cursorLocation = { loc.x, loc.y }
    end)
end

---@class ui.preview.events.hub
local hub = {}
hub.__index = hub
hub.__name = 'hub'

---@return ui.preview.events.hub
function hub.new(id, tag, loglevel)
    local o = {}
    setmetatable(o, hub)

    o.id = id
    o.log = hs.logger.new(tag or 'ui.preview.events.hub', loglevel or 'warning')
    o.state = hs.watchable.new('X:['..id..']:>', true)
    o.pathMask = 'X:['.. id .. '/%s]:>'
    o.ctrl = canvasController.new(o.pathMask)

    return o
end

---@return fun(canvas: hs.canvas, eventType: string, elementId: string, x: number, y: number)
function hub:cbForMouseEvents(elementIdOverride)
    local function callback(canvas, eventType, elementId, x, y)
        if elementIdOverride ~= nil then
            elementId = elementIdOverride
        end
        self.state[eventType] = { hs.timer.absoluteTime(), canvas, elementId, x, y }
        self.ctrl:onMouseEvent(canvas, eventType, elementId, x, y)
    end

    return callback
end


---@class ui.preview.events.observer
local observer = {}
observer.__index = observer
observer.__name = 'watcher'

---@param elementIds string[]
---@return ui.preview.events.observer
function hub:attach(elementIds)
    local o = {}
    o.elementIds = elementIds
    o.ctx = {}
    o.log = hs.logger.new('ui.preview.events.observer', 'debug')

    o.config = {
        tapTimeout = 0.2,
        longTapTimeout = 0.7,
    }

    setmetatable(o, observer)
    o:hooks({
        onFocusLost = function(ctx) o.log.d("onSessionBegin") end,
        onSessionBegin = function(ctx) o.log.d("onSessionBegin") end,
        onSessionEnd = function(ctx) o.log.d("onSessionEnd") end,
        onTap = function(ctx) o.log.d("onTap") end,
        onLongTap = function(ctx) o.log.d("onLongTap") end,
        onClick = function(ctx) o.log.d("onClick") end,
        onDoubleClick = function(ctx) o.log.d("onDoubleClick") end,
        onDrag = function(ctx) o.log.d("onDrag") end,
        onMoveBegin = function(ctx) o.log.d("onMoveBegin") end,
        onMoveEnd = function(ctx) o.log.d("onMoveEnd") end,

        doFocus = function(elementId) self[elementId]:change('isFocused', true) end,
    })

    hs.fnutils.each(elementIds, function(elementId)
        local ctx = {}
        self[elementId] = hs.watchable.watch(string.format(self.pathMask, elementId), '*',function(watcher, path, key, old, new)
            self.log.df("%s %s; [%s] => [%s]", path, key, repr(old), repr(new))
            if key == 'isSelected' then
                if new then
                    o:hooks().onSessionBegin(ctx)
                else
                    o:hooks().onSessionEnd(ctx)
                end
            end
            if key == 'isFocused' then
                if new == false then
                    o:hooks().onFocusLost(ctx)
                end
            end
            if key == 'actionRequested' then
                new:doOnce(function() o:hooks().onClick(ctx) end)
            end
        end)
    end)

    return o
end



---@param newActionMap { [string]: fun(x: integer, y: integer) }
---@return { [string]: fun(x: integer, y: integer) }
function observer:actionMap(newActionMap)
    if newActionMap ~= nil then
        self.__actionMap = newActionMap
    end
    if self.__actionMap == nil then
        self.__actionMap = {}
    end
    return self.__actionMap
end

---@param { [string]: fun() }
function observer:hook(name, fn)
    if self.__hooks == nil then
        self.__hooks = {}
    end
    self.__hooks[name] = fn
    return self
end

---@param h { [string]: fun() }
---@return { [string]: fun() }
function observer:hooks(h)
    if h ~= nil then
        self.__hooks = h
        return self
    end
    if self.__hooks == nil then
        self.__hooks = {}
    end
    return self.__hooks
end

function observer:start()
    --self:resume()
    return self
end

function observer:stop()
    --self:reset()
    --self:idle()
    --self:pause()
    return self
end

return hub
