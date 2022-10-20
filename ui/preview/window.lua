---@class ui.preview.window
local preview = {}
preview.__index = preview
preview.__name = 'preview'

---@param s ui.preview.state | nil
---@return ui.preview.state | ui.preview.window
function preview:state(s)
    if s ~= nil then
        if self._state ~= nil then self._state.__onUpgrade = function() end end
        s.__onUpgrade = function()
            self:apply()
        end
        self._state = s
        return self
    end
    return self._state
end

---@param s ui.preview.state | nil
---@return ui.preview.state | ui.preview.window
function preview:rState(s)
    if s ~= nil then
        self._rState = s
        return self
    end
    return self._rState
end

---@param c hs.canvas | nil
---@return hs.canvas | ui.preview.window
function preview:canvas(c)
    if c ~= nil then
        self._canvas = c
        return self
    end
    return self._canvas
end

---@param w ui.preview.events.watcher | nil
---@return ui.preview.events.watcher | ui.preview.window
function preview:previewEvents(w)
    if w ~= nil then
        self._previewEvents = w
        return self
    end
    return self._previewEvents
end

---@param hook fun(isLocked: boolean) | nil
---@return fun(isLocked: boolean) | ui.preview.window
function preview:onLockedHook(hook)
    if hook ~= nil then
        self:state():hooks().onLock = hook
        return self:apply()
    end
    if self:state():hooks().onLock == nil then
        return function(locked) end
    end
    return self:state():hooks().onLock
end

---@param hook fun() | nil
---@return fun() | ui.preview.window
function preview:onClickedHook(hook)
    if hook ~= nil then
        self:state():hooks().onClick = hook
        return self
    end
    if self:state():hooks().onClick == nil then
        return function() end
    end
    return self:state():hooks().onClick
end

---@param previewArea hs.geometry
---@return ui.preview.window | ui.preview.window
function preview:new(previewArea)
    ---@type ui.preview.window
    local o = {}
    setmetatable(o, self)

    local hub = require 'ui.preview.events':new('ui.preview.window', 'info')
    local sessEndTimer = hs.timer.delayed.new(0.1, function()
        o:apply(o:state():highlighted(false))
    end)

    o
    :previewEvents(
        hub:attach({'background'})
            :hook('onSessionBegin', function(ctx)
                sessEndTimer:stop()
                o:apply(o:state():highlighted(true))
            end)
            :hook('onSessionEnd', function()
                sessEndTimer:start()
            end)
            :hook('onLongTap', function()
            end)
            :hook('onClick', function()
                if hs.eventtap.checkKeyboardModifiers().alt then
                    o:toggleLock()
                else
                    o:onClickedHook()()
                end
            end)
        :start())
    :rState(ui.preview.state:new())
    :state(ui.preview.state:new())
    :canvas(hs.canvas.new(previewArea):appendElements({
            type = 'image',
            id = 'background',
            image = o:rState():background(),
            imageAlignment = 'left',
            imageAlpha = 1,
            padding = 5,
            trackMouseByBounds = true,
            trackMouseEnterExit = true,
            trackMouseDown = true,
            trackMouseUp = true,
            trackMouseMove = false,
            withShadow = true,
        }):alpha(1.0):show()
        :clickActivating(false)
        :canvasMouseEvents(false, false, false, false)
        :mouseCallback(hub.cbForMouseEvents)
        :level(hs.canvas.windowLevels.dock)
        :wantsLayer(false)
        :behaviorAsLabels({ "canJoinAllSpaces", 'stationary'}))
    return o
end

function preview:apply(remoteState)
    if remoteState == nil then
        remoteState = self:state()
    end
    if self:rState():background() ~= remoteState:background()  then
        self:canvas():elementAttribute(1, 'image', remoteState:background())
        ---@diagnostic disable-next-line: param-type-mismatch
        self:rState():background(remoteState:background())
    end
    if self:rState():shifted() ~= remoteState:shifted() then
        self:canvas():elementAttribute(1, 'imageAlignment', remoteState:shifted() and 'right' or 'left')
    end
    if self:rState():locked() ~= remoteState:locked() then
        ---@diagnostic disable-next-line: param-type-mismatch
        self:rState():locked(remoteState:locked())
    end
    if self:rState():focused() ~= remoteState:focused() then
        ---@diagnostic disable-next-line: param-type-mismatch
        self:rState():focused(remoteState:focused())
    end
    if self:rState():highlighted() ~= remoteState:highlighted() then
        self:canvas():elementAttribute(1, 'imageAlpha', remoteState:highlighted() and 1.0 or 1.0)
        ---@diagnostic disable-next-line: param-type-mismatch
        self:rState():highlighted(remoteState:highlighted())
    end
    if self:rState():visible() ~= remoteState:visible() then
        if remoteState:visible() then
            self:canvas():show(0.5)
        else
            self:canvas():hide(0.5)
        end
        ---@diagnostic disable-next-line: param-type-mismatch
        self:rState():visible(remoteState:visible())
    end
    return self
end

function preview:show()
    self:apply(self:state():visible(true))
    return self
end

function preview:focused()
    self:apply(self:state():visible(true))
    return self
end

function preview:unfocused()
    self:apply(self:state():visible(false))
    return self
end

function preview:hide()
    self:apply(self:state():visible(false))
    return self
end

function preview:highlight()
    self:apply(self:state():highlighted(true))
    return self
end

function preview:toggleLock()
    local isLocked = not self:state():locked()
    self:apply(self:state():locked(isLocked))
    ---@diagnostic disable-next-line: param-type-mismatch
    self:onLockedHook()(self:state():locked())
    return self
end

function preview:updatePreview(img)
    self:state():background(img)
    self:apply()
    return self
end

function preview:reset()
    self:state():reset()
    self:apply()
    return self
end

return preview
