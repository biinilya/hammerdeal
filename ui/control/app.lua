---@class ui.control.app
---@field name string
---@field log hs.logger
---@field cfg ui.cfg
---@field screen ui.preview.state
---@field layout ui.control.layout
---@field attached boolean
---@field hsApp hs.application
---@field windows {hs.window: number}
---@field focusHist hs.window[]
---@field transitions {string: fun()}
---@field snapshotter hs.timer
---@field state string
local app = {}
app.__index = app
app.__lastId = 0
app.__globalConfig = ui.config:new('ui.control.app')

hs.hotkey.bind({ "alt" }, "1", function()
    app.__globalConfig:set('live.locked', false)
    app.__globalConfig:set('live.floating', false)
    hs.reload()
end)

hs.hotkey.bind({ "alt" }, "2", function()
    app.__globalConfig:set('live.locked', true)
    app.__globalConfig:set('live.floating', true)
    hs.reload()
end)

hs.hotkey.bind({ "alt" }, "3", function()
    app.__globalConfig:set('live.locked', true)
    app.__globalConfig:set('live.floating', false)
    hs.reload()
end)

hs.hotkey.bind({ "alt" }, "4", function()
    app.__globalConfig:set('live.locked', false)
    app.__globalConfig:set('live.floating', true)
    hs.reload()
end)

---@return ui.control.app
function app:new(appName, layout, app)
    local obj = {}
    setmetatable(obj, self)
    return obj:init(appName, layout, app)
end

---@param appName string
---@param layout ui.control.layout
---@param app hs.application | nil
---@return ui.control.app
function app:init(appName, layout, app)
    self.name = appName
    self.hsApp = app
    self.bundleID = 'com.apple.finder'
    if app ~= nil and app:bundleID() ~= nil then
        self.bundleID = app:bundleID()
    end
    self.layout = layout
    self.attached = false
    self.cfg = ui.config:new(appName)
    self.log = hs.logger.new(appName, 'warning')
    self.log.f('Init app [%s]', appName)
    self.state = 'init'
    self.windows = {}
    self.windowsCount = 0

    self.screen = ui.preview.state:new()
        :background(ui.preview.thumbnailS(self.bundleID))
        :logo(ui.preview.logo(self.bundleID))
        :visible(true)
    self.screen.__app = self
    if self.cfg:get('locked') then
        self.screen:locked(true)
    end
    self.screen:apply()
    self.screen:hooks().onLock = function ()
        if self.screen:locked() then
            self.cfg:set('locked', hs.timer.secondsSinceEpoch())
        else
            self.cfg:set('locked', nil)
        end
    end
    self.screen:hooks().onClick = ui.partial(self.activate, self)
    self.flowTime = hs.timer.delayed.new(300, function ()
        if not self.hsApp:isFrontmost() then return end
        self.cfg:event('flow')
        self.flowTime:start()
    end)
    self.snapshotter = hs.timer.delayed.new(hs.math.randomFloat(), ui.fn.partial(self.doSnapshot, self))
    self.transitions = {
        ['init->started'] = function()
            self.transitions['init->starting']()
            self.transitions['starting->started']()
        end,
        ['init->focused'] = function()
            self.transitions['init->starting']()
            self.transitions['starting->started']()
            self.transitions['started->focused']()
        end,
        ['starting->stopped']  = function()
            self.transitions['starting->started']()
            self.transitions['started->stopped']()
        end,
        ['starting->focused'] = function()
            self.transitions['starting->started']()
            self.transitions['started->focused']()
        end,
        ['focused->stopped'] = function()
            self.transitions['focused->started']()
            self.transitions['started->stopped']()
        end,
        -------------------------------------------
        ['init->starting'] = function()
            self.log.f('Starting app [%s]', appName)
            self.screen:background(ui.preview.thumbnail(self.bundleID)):apply()
            self.state = 'starting'
        end,
        ['init->stopped'] = function()
            self.log.f('App [%s] is stopped', appName)
            self.screen:background(ui.preview.thumbnailS(self.bundleID)):apply()
            self.state = 'stopped'
        end,
        ['starting->started'] = function()
            self.log.f('App [%s] has started', appName)
            self.screen:background(ui.preview.thumbnail(self.bundleID)):apply()
            self.state = 'started'
            if self.activateOnStart then
                self:activate()
                self.activateOnStart = false
            end
        end,
        ['started->focused'] = function()
            self.log.f('App [%s] has been focused', appName)
            self.screen:focused(true):apply()
            self.cfg:event('focused')
            self.state = 'focused'

            local autoLayout = (self.cfg:get('layout') or hs.keycodes.layouts()[1])
            hs.keycodes.setLayout(autoLayout)
            self:enforceLayout(true)
            local checkLayout = nil
            checkLayout = hs.timer.delayed.new(1, function()
                if self.state ~= 'focused' then
                    return
                end
                checkLayout:start()
                self:enforceLayout()
            end):start()
            self.flowTime:start()
        end,
        ['started->stopped'] = function()
            self.log.f('App [%s] has stopped', appName)
            self.screen:background(ui.preview.thumbnailS(self.bundleID)):apply()
            self.state = 'stopped'
            self.flowTime:stop()
        end,
        ['focused->started'] = function()
            self.log.f('App [%s] has lost focus', appName)
            self.screen:focused(false):apply()
            self.state = 'started'
        end,
        ['stopped->starting'] = function()
            self.log.f('App [%s] is restarting', appName)
            self.screen:background(ui.preview.thumbnail(self.bundleID)):apply()
            self.state = 'starting'
        end,
    }
    return self
end

function app:enforceLayout(forceFront)
    if self.screen.__belongsTo then
        self.screen.__belongsTo.__app:enforceLayout(forceFront)
        return
    end
    local currentLayout = hs.keycodes.currentLayout()
    if autoLayout ~= currentLayout then
        self.cfg:set('layout', currentLayout)
        autoLayout = currentLayout
    end
    if self.screen ~= nil and self.layout ~= nil then
        local tileWindows = {}
        if self.hsApp:mainWindow() ~= nil then
            table.insert(tileWindows, self.hsApp:mainWindow())
        else
            for _, win in ipairs(self.hsApp:allWindows()) do
                if win:isStandard() and win:subrole() == "AXStandardWindow" then
                    table.insert(tileWindows, win)
                    break
                end
            end
        end
        for _, joined in ipairs(self.screen.__joinedTo) do
            for idx, window in ipairs(joined.__mainWindow) do
                if window then
                    table.insert(tileWindows, window)
                    if forceFront then
                        window:raise()
                    end
                end
            end
        end
        for _, window in ipairs(tileWindows) do
            if forceFront then
                window:raise()
            end
        end
        if #tileWindows == 1 then
            tileWindows[1]:setFrame(self.layout.workspace)
        elseif #tileWindows == 2 then
            local workspace = self.layout.workspace:copy()
            local left = workspace:copy()
            local right = workspace:copy()
            left.w = workspace.w * 6 / 10
            right.x = workspace.x + left.w
            right.w = workspace.w * 4 / 10
            tileWindows[1]:setFrame(left)
            tileWindows[2]:setFrame(right)
        elseif #tileWindows == 3 then
            local workspace = self.layout.workspace:copy()
            local left = workspace:copy()
            local topRight = workspace:copy()
            local bottomRight = workspace:copy()
            left.w = workspace.w / 2
            topRight.x = workspace.x + left.w
            bottomRight.x = workspace.x + left.w
            topRight.h = workspace.h / 2
            bottomRight.y = workspace.y + topRight.h
            bottomRight.h = workspace.h / 2
            topRight.w = workspace.w / 2
            bottomRight.w = workspace.w / 2
            tileWindows[1]:setFrame(left)
            tileWindows[2]:setFrame(topRight)
            tileWindows[3]:setFrame(bottomRight)
        end

        --hs.window.tiling.tileWindows(tileWindows, self.layout.workspace, 1, true, true, 0)
    end
end

---@param status string
---@param appObject hs.application
function app:changeStatusTo(status, appObject)
    if self.screen.__belongsTo then
        self.layout:detach(self.name)
    end

    local transition = string.format('%s->%s', self.state, status)
    if self.transitions[transition] then
        self.transitions[transition]()
    else
        self.log.f('Ignored transition [%s]', transition)
    end
    if appObject ~= nil then
        self.hsApp = appObject
    end
    
    if self.cfg:get('locked') or (self.hsApp ~= nil and #self.hsApp:allWindows() > 0) then
        if not self.attached then
            self.attached = true
            self.layout:attach(self.name, self.screen, self.cfg)
        end
    else
        if self.attached then
            self.attached = false
            self.layout:detach(self.name)
        end
    end
    self.screen:mainWindow(self.hsApp:mainWindow())
end

---@param windowObject hs.window
function app:registerWindow(windowObject)
    self.windows[windowObject] = 1
    self.snapshotter:start()
    local count = 0
    for _, _ in pairs(self.windows) do
        count = count + 1
    end
    if self.windowsCount == 0 and count ~= 0 then
        self.windowsCount = count
        self:changeStatusTo(self.state, self.hsApp)
    end
    self.windowsCount = count
end

---@param windowObject hs.window
function app:deregisterWindow(windowObject)
    self.windows[windowObject] = nil
    local count = 0
    for _, _ in pairs(self.windows) do
        count = count + 1
    end
    if self.windowsCount ~= 0 and count == 0 then
        self.windowsCount = count
        self:changeStatusTo(self.state, self.hsApp)
    end
    self.windowsCount = count
end

---@param windowObject hs.window
function app:focusWindow(windowObject)
    for windowID, _ in pairs(self.windows) do
        self.windows[windowID] = 1
    end
    self.windows[windowObject] = 2
    self.snapshotter:start()
end

function app:activate()
    ---@type hs.window
    local w
    for window, focused in pairs(self.windows) do
        ---@type hs.window
        w = window
        if focused == 2 then
            break   
        end
    end
    if self.hsApp:isRunning() then
        if self.hsApp:isHidden() then
            self.hsApp:unhide()
        end
        if w ~= nil then
            if w:isMinimized() then w:unminimize() end
            w:focus()
            return
        end
        self.hsApp:activate()
        return
    end
    self:changeStatusTo('stopped', self.hsApp)
    self.windows = {}
    self.hsApp = hs.application.open(self.hsApp:bundleID(), 5, 5)
    self.activateOnStart = true
end

function app:doSnapshot()
    if not self.screen or not self.screen.__notifyPriority then
        self.snapshotter:start()
        return
    end
    self.snapshotter:start(self.screen.__notifyPriority)

    local locked = self.screen:locked()
    local confKey = string.format('live.%s', locked and 'locked' or 'floating')
    if not self.__globalConfig:get(confKey) then
        return
    end

    ---@type hs.window
    local w = nil
    for window, focused in pairs(self.windows) do
        w = window
        if focused == 2 then
            break
        end
    end
    if not w then
        return
    end


    local s = w:snapshot(true)
    if s ~= nil then
        self.screen:background(s:bitmapRepresentation({ w = 276, h = 200 })):apply()
        pcall(function() hs.image.__gc(s) end)
    end
end

return app


-- function app:primaryWindow()
--     if #self.focusHist > 0 then
--         return self.focusHist[#self.focusHist]
--     elseif #self.windows > 0 then
--         return self.windows[#self.windows]
--     end
-- end

-- function app:otherWindows()
--     local primary = self:primaryWindow()
--     local focused = ui.fn.copy(self.focusHist)
--     local all = ui.fn.copy(self.windows)
-- end

-- function app:onFocus(status)
--     self.screen:focused(status):apply()
--     if status then
--         self.cfg:notify('focused')
--     end
-- end

-- function app:onWindowEvent(w, event)
--     -- self.focusHist = ui.ifilter(self.focusHist, ui.ne(w))
--     -- table.insert(self.focusHist, w)
-- end

-- function app:onWindowOpen(w)
--     table.insert(self.windows, w)
--     if #self.windows == 1 then
--         self:onOnline(w)
--     end
-- end

-- function app:onWindowClose(w)
--     self.windows = ui.ifilter(self.windows, ui.ne(w))
--     self.focusHist = ui.ifilter(self.focusHist, ui.ne(w))
--     if #self.windows == 0 then
--         self:onOffline(w)
--     end
-- end

-- function app:animateLaunch(status)
-- end

-- function app:onRunning(status)
-- end

-- function app:onOnline(w)
--     self.log.df('onOnline()')
-- end

-- function app:onOffline(w)
--     self.log.df('onOffline()')
-- self     self.screen:background(i(preview.thumbnail(obj.bundleID))
-- end


-- function app:onViewOpened(window, appName)

-- self.log.df('onViewOpened(%s, %s)', window:title(), appName)
-- self.ctx[window] = {
-- state = require('ui.preview.state'):new():visible(true):background(self:thumbnailGen()),
-- focusTracker = function(w)
-- self.ctx[window]['state']:focused(window == w)
-- table.insert(ctx.__focusgonecb, self.ctx[window]['focusTracker'])
-- end,
-- snapshotter = hs.timer.doEvery(1, function()
-- self.cfg:notify('e.thumbnail')
-- self.ctx[window]['state']:background(window:snapshot())
-- end)
-- }
-- self.ctx[window]['state']:hooks().onClick = function()
-- window:focus()
-- end
-- self.ctx[window]['focusTracker'](self.__focused)
-- ctx.__layout:attach(window, self.ctx[window][state], self.cfg)
-- end
--
-- function app:onViewClosed(window, appName)
-- self.log.df('onViewClosed(%s, %s)', window:title(), appName)
-- ctx.__layout:detach(window)
-- self.ctx[window][state]:reset()
-- self.ctx[window]['snapshotter']:stop()
-- hs.timer.doAfter(60, function()
-- self.ctx[window] = nil
-- end)
-- end
