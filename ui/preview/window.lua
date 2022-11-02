---@class ui.preview.window
---@field delayedClick hs.timer.delayed
local preview = {}
preview.__index = preview
preview.__name = 'preview'
preview.__digitsMap = { '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⓪' }
preview.__lettersMap = { '🅐', '🅑', '🅒', '🅓', '🅔', '🅕', '🅖', '🅗', '🅘', '🅙', '🅚', '🅛',
    '🅜', '🅝', '🅞', '🅟', '🅠', '🅡', '🅢', '🅣', '🅤', '🅥', '🅦', '🅧', '🅨', '🅩' }

---@param s ui.preview.state | nil
---@return ui.preview.state | ui.preview.window
function preview:state(s)
    if s ~= nil then
        self._state = s
        return self:apply()
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

---@param w ui.preview.events.observer | nil
---@return ui.preview.events.observer | ui.preview.window
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

---@param canvas hs.canvas
---@param event string
---@param details any
function preview:onDND(canvas, event, details)
    -- the drag entered our view frame
    if event == "enter" then
        -- could inspect details and reject with `return false`
        -- but we're going with the default of true
        canvas:elementAttribute(1, 'action', 'skip')
        canvas:elementAttribute(4, 'action', 'skip')
        canvas:elementAttribute(2, 'action', 'fill')
        self.delayedClick:start()
        return true


        -- the drag exited our view domain without a release (or we returned false for "enter")
    elseif event == "exit" or event == "exited" then
        -- return type ignored

        canvas:elementAttribute(1, 'action', 'fill')
        canvas:elementAttribute(4, 'action', 'fill')
        canvas:elementAttribute(2, 'action', 'skip')
        self.delayedClick:stop()
        -- the drag finished -- it was released on us!

    elseif event == "receive" then
        local name = details.pasteboard
        hs.pasteboard.writeAllData(nil, hs.pasteboard.readAllData(name))
        canvas:elementAttribute(1, 'action', 'fill')
        canvas:elementAttribute(4, 'action', 'fill')
        canvas:elementAttribute(2, 'action', 'skip')
        self.delayedClick:stop()
    end
end

---@param previewArea hs.geometry
---@param index number
---@param hub ui.preview.events.hub
---@return ui.preview.window | ui.preview.window
function preview:new(id, hub, previewArea)
    ---@type ui.preview.window
    local o = {}
    setmetatable(o, self)

    o.delayedClick = hs.timer.delayed.new(1.0, function()
        o:state():hooks().onClick()
    end)

    o:previewEvents(
        hub:attach({ id .. '/thumbnail' })
        :hook('onMoveBegin', function(ctx)
            ctx.avatar = hs.drawing.image(o:canvas():frame(), o:canvas():imageFromCanvas()):show()
        end)
        :hook('onMoveEnd', function(ctx)
            ctx.avatar:setTopLeft(hs.mouse.getRelativePosition()):hide()
        end)
        :hook('onDrag', function(ctx)
            ctx.avatar:setTopLeft(hs.mouse.getRelativePosition())
            ctx.state = o:state()
        end)
        :hook('onClick', function()
            if hs.eventtap.checkKeyboardModifiers().alt then
                o:toggleLock()
            else
                o:state():focused(true)
                o:previewEvents():hooks()['doFocus'](id .. '/thumbnail')
                o:apply()
                o:onClickedHook()()
            end
            return false
        end)
        :hook('onTap', function(ctx)
            return true
        end)
        :hook('onSessionBegin', function(ctx)
            o:state():highlighted(true)
            o:apply()
            return true
        end)
        :hook('onSessionEnd', function(ctx)
            o:state():highlighted(false)
            o:apply()
            return true
        end)
        :hook('onDropBegin', function(ctx)
            o:canvas():elementAttribute(1, 'action', 'skip')
            o:canvas():elementAttribute(4, 'action', 'skip')
            o:canvas():elementAttribute(2, 'action', 'fill')
            ctx.state = o:state()
        end)
        :hook('onDropEnd', function(ctx)
            o:canvas():elementAttribute(1, 'action', 'fill')
            o:canvas():elementAttribute(4, 'action', 'fill')
            o:canvas():elementAttribute(2, 'action', 'skip')
            ctx.state = nil
        end)
        :hook('onDropReceived', function(ctx, otherCtx)
            ctx.state:isMasterTo(otherCtx.state)
            otherCtx.state:hooks()['onClick']()
            hs.timer.doAfter(0.5, function()
                o:onClickedHook()()
            end)
        end)
        :hook('onFocusLost', function(ctx)
            o:state():focused(false)
            o:apply()
            return true
        end)
        :start()
    )
    :rState(ui.preview.state:new())
    :state(ui.preview.state:new())
        :canvas(hs.canvas.new(previewArea):appendElements({
            type = 'image',
            action = 'fill',
            image = o:rState():background(),
            imageAlignment = 'left',
            imageAlpha = 1,
            withShadow = true,
            padding = 5,
            antialias = true,
        }, {
            type = 'text',
            action = 'skip',
            textSize = 100,
            text = 'æ',
            textColor = { white=1, alpha = 0.5 },
            fillGradientCenter = { x = 0, y = 0 },
            textAlignment = 'center',
            withShadow = true,
            padding = 5,
        }, {
            type = 'rectangle',
            action = 'skip',
            strokeColor = { white = 1, alpha = 0.5 },
            strokeWidth = 1,
        }, {
            type = 'image',
            action = 'fill',
            image = o:rState():logo(),
            imageAlignment = 'right',
            imageAlpha = 0.7,
            withShadow = true,
            padding = 5,
            antialias = true,

        }):alpha(1.0)
        :clickActivating(false)
        :canvasMouseEvents(true, true, true, false)
        :mouseCallback(hub:cbForMouseEvents(id .. '/thumbnail'))
        :level(hs.canvas.windowLevels.dock)
        :draggingCallback(ui.fn.partial(o.onDND, o))
        :wantsLayer(true)
        :behaviorAsLabels({
            "transient",
            "canJoinAllSpaces",
        }):show())
    return o
end

function preview:apply(remoteState)
    if remoteState == nil then
        remoteState = self:state()
    end
    if self:rState():background() ~= remoteState:background() then
        self:canvas():elementAttribute(1, 'image', remoteState:background())
        pcall(function() hs.image.__gc(remoteState:background()) end  )
        self:rState():background(remoteState:background())
        ---@diagnostic disable-next-line: param-type-mismatch
    end
    if self:rState():logo() ~= remoteState:logo() then
        self:canvas():elementAttribute(4, 'image', remoteState:logo())
        pcall(function() hs.image.__gc(remoteState:logo()) end  )
    end
    if  self:rState():locked() ~= remoteState:locked() or
        self:rState():focused() ~= remoteState:focused()
    then
        local l = self:canvas():topLeft()
        l.x = 0
        if remoteState:locked() then l.x = 50 end
        if remoteState:focused() then l.x = 100 end
        self:canvas():topLeft(l)
        --self:canvas():elementAttribute(2, 'frame', self:canvas():elementBounds(1))
        self:rState():locked(remoteState:locked())
        self:rState():focused(remoteState:focused())
    end
    if self:rState():highlighted() ~= remoteState:highlighted() then
        self:canvas():elementAttribute(3, 'action', remoteState:highlighted() and 'stroke' or 'skip')
        --self:canvas():elementAttribute(4, 'action', remoteState:highlighted() and 'fill' or 'skip')
        ---@diagnostic disable-next-line: param-type-mismatch
        self:rState():highlighted(remoteState:highlighted())
    end
    if self:rState():visible() ~= remoteState:visible() then
        if remoteState:visible() then
            self:canvas():elementAttribute(1, 'action', 'fill')
            self:canvas():elementAttribute(4, 'action', 'fill')
        else
            self:canvas():elementAttribute(1, 'action', 'skip')
            self:canvas():elementAttribute(4, 'action', 'skip')
        end
        ---@diagnostic disable-next-line: param-type-mismatch
        self:rState():visible(remoteState:visible())
    end
    collectgarbage('step')
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

function preview:reset()
    self:state():reset()
    self:apply()
    return self
end

return preview
