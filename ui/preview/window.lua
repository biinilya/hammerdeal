local frame = require 'ui.frame'
local events = require 'ui.preview.events'
local state = require 'ui.preview.state'

---@class ui.preview.window
local preview = {}
preview.__index = preview
preview.__name = 'preview'

---@param s ui.preview.state
---@return ui.preview.state | ui.preview.window
function preview:state(s)
    if s ~= nil then
        self._state = s
        return self
    end
    return self._state
end

---@param s ui.preview.state
---@return ui.preview.state | ui.preview.window
function preview:rState(s)
    if s ~= nil then
        self._rState = s
        return self
    end
    return self._rState
end

---@param c hs.canvas
---@return hs.canvas | ui.preview.window
function preview:canvas(c)
    if c ~= nil then
        self._canvas = c
        return self
    end
    return self._canvas
end

---@param w ui.preview.events.watcher
---@return ui.preview.events.watcher | ui.preview.window
function preview:previewEvents(w)
    if w ~= nil then
        self._previewEvents = w
        return self
    end
    return self._previewEvents
end

---@param w ui.preview.events.watcher
---@return ui.preview.events.watcher | ui.preview.window
function preview:lockerEvents(w)
    if w ~= nil then
        self._lockerEvents = w
        return self
    end
    return self._lockerEvents
end

---@param hook fun(isLocked: boolean)
---@return fun(isLocked: boolean) | ui.preview.window
function preview:onLockedHook(hook)
    if hook ~= nil then
        self._lockedHook = hook
        return self
    end
    if self._lockedHook == nil then
        return function(locked) end
    end
    return self._lockedHook
end

---@param hook fun()
---@return fun() | ui.preview.window
function preview:onClickedHook(hook)
    if hook ~= nil then
        self._clickedHook = hook
        return self
    end
    if self._clickedHook == nil then
        return function() end
    end
    return self._clickedHook
end

---@param previewArea ui.frame
---@param windowArea ui.frame
---@return ui.preview.window | ui.preview.window
function preview:new(previewArea)
    ---@type ui.preview.window
    local o = {}
    setmetatable(o, self)

    local hub = require 'ui.preview.events':new('ui.preview.window', 'info')
    local sessEndTimer = hs.timer.delayed.new(0.1, function()
        o:state():highlighted(false):lockerVisible(false):apply()
    end)

    o
    :lockerEvents(
        hub:attach({'locker'})
            :hook('onSessionBegin', function(ctx)
                sessEndTimer:stop()
                o:state():highlighted(true):lockerHighlighted(true):lockerVisible(true):apply()
            end)
            :hook('onSessionEnd', function(ctx)
                o:state():highlighted(true):lockerHighlighted(false):apply()
                sessEndTimer:start()
            end)
            :hook('onClick', function()
                local isAlt = hs.eventtap.checkKeyboardModifiers()['alt']
                if isAlt then
                    o:toggleLock():apply()
                end
            end)
        :start())
    :previewEvents(
        hub:attach({'background'})
            :hook('onSessionBegin', function(ctx)
                sessEndTimer:stop()
                o:state():highlighted(true):apply()
            end)
            :hook('onSessionEnd', function()
                sessEndTimer:start()
            end)
            :hook('onLongTap', function()
                o:state():lockerVisible(true):apply()
            end)
            :hook('onClick', function()
                o:onClickedHook()()
            end)
        :start())
    :rState(state:new(o))
    :state(state:new(o))
    :canvas(hs.canvas.new(previewArea:rect()):appendElements({
            type = 'image',
            id = 'background',
            image = o:rState():background(),
            imageAlignment = 'left',
            imageAlpha = 1,
            padding = previewArea:rect().h * 0.05,
            trackMouseByBounds = false,
            trackMouseEnterExit = true,
            trackMouseDown = true,
            trackMouseUp = true,
            trackMouseMove = false,
        }):alpha(1.0)
        :mouseCallback(hub.cbForMouseEvents)
        :level(hs.canvas.windowLevels.floating)
        :wantsLayer(true)
        :behaviorAsLabels({ "canJoinAllSpaces", 'stationary'}))
    return o
end

function preview:apply()
    if self:rState():background() ~= self:state():background()  then
        self:canvas():elementAttribute(1, 'image', self:state():background())
        self:rState():background(self:state():background())
    end
    if self:rState():shifted() ~= self:state():shifted() then
        self:canvas():elementAttribute(1, 'imageAlignment', self:state():shifted() and 'right' or 'left')
    end
    if self:rState():locked() ~= self:state():locked() then
        if self:rState():lockerVisible() then
            self:canvas():elementAttribute(2, 'image', self:state():lockerImg())
        end
        self:rState():locked(self:state():locked())
    end
    if self:rState():focused() ~= self:state():focused() then
        self:rState():focused(self:state():focused())
    end
    if self:rState():lockerVisible() ~= self:state():lockerVisible() then
        if self:state():lockerVisible() then
            self:canvas()[2] = {
                type = 'image',
                id = 'locker',
                image = self:state():lockerImg(),
                imageAlignment = 'left',
                imageAlpha = 1.0,
                frame = ui.frame:fractions(0.1, 0.3, 0.3, 0.4):rect(self:canvas():frame()),
                trackMouseByBounds = false,
                trackMouseEnterExit = true,
                trackMouseDown = true,
                trackMouseUp = true,
                trackMouseMove = false,
            }
        end
        self:rState():lockerVisible(self:state():lockerVisible())
        if not self:state():lockerVisible() then
            self:canvas()[2] = nil
        end
    end
    if self:rState():lockerHighlighted() ~= self:state():lockerHighlighted() then
        local alpha = (self:state():lockerHighlighted() and 1.0 or 1.0) * (self:state():lockerVisible() and 1 or 0)
        if self:rState():lockerVisible() then
            self:canvas():elementAttribute(2, 'imageAlpha', alpha)
        end
        self:rState():lockerHighlighted(self:state():lockerHighlighted())
    end
    if self:rState():highlighted() ~= self:state():highlighted() then
        self:canvas():elementAttribute(1, 'imageAlpha', self:state():highlighted() and 1.0 or 1.0)
        self:rState():highlighted(self:state():highlighted())
    end
    if self:rState():visible() ~= self:state():visible() then
        if self:state():visible() then
            self:canvas():show()
        else
            self:canvas():hide()
        end
        self:rState():visible(self:state():visible())
    end
    return self
end

function preview:show()
    self:state():visible(true):apply()
    return self
end

function preview:focused()
    self:state():visible(true):apply()
    return self
end

function preview:unfocused()
    self:state():visible(false):apply()
    return self
end

function preview:hide()
    self:state():visible(false):apply()
    return self
end

function preview:highlight()
    self:state():highlighted(true):apply()
    return self
end

function preview:toggleLock()
    self:state():locked(not self:state():locked()):apply()
    self:onLockedHook()(self:state():locked())
    return self
end

function preview:updatePreview(img)
    self:state():background(img)
    self:state():apply()
    return self
end

function preview:reset()
    self:state():reset():apply()
    return self
end

return preview