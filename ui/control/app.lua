---@class ui.control.app
---@field name string
---@field log hs.logger
---@field cfg ui.cfg
---@field screen ui.control.view | any
---@field layout ui.control.layout
---@field attached boolean
---@field hsApp hs.application
---@field windows hs.window[]
---@field focusHist hs.window[]
---@field transitions {string: fun()}
---@field state string
local app = {}
app.__index = app
app.__lastId = 0

---@param appName string
---@param layout ui.control.layout
---@param app hs.application | nil
---@return ui.control.app
function app:new(appName, layout, app)
    local obj = {}
    setmetatable(obj, self)
    obj.name = appName
    obj.hsApp = app
    obj.bundleID = 'com.apple.finder'
    if app ~= nil and app:bundleID() ~= nil then
        obj.bundleID = app:bundleID()
    end
    obj.layout = layout
    obj.attached = false
    obj.cfg = ui.config:new(appName)
    obj.log = hs.logger.new(appName, 'debug')
    obj.log.f('Init app [%s]', appName)
    obj.state = 'init'
    obj.screen = ui.preview.state:new()
        :background(ui.preview.thumbnailS(obj.bundleID))
        :visible(true)
    if obj.cfg:get('locked') then
        obj.screen:locked(true)
    end
    obj.screen:apply()
    obj.screen:hooks().onLock = function ()
        if obj.screen:locked() then
            obj.cfg:set('locked', hs.timer.secondsSinceEpoch())
        else
            obj.cfg:set('locked', nil)
        end
    end
    obj.flowTime = hs.timer.delayed.new(300, function ()
        if not obj.hsApp:isFrontmost() then return end
        obj.cfg:event('flow')
        obj.flowTime:start()
    end)
    obj.transitions = {
        ['init->started'] = function()
            obj.transitions['init->starting']()
            obj.transitions['starting->started']()
        end,
        ['init->focused'] = function()
            obj.transitions['init->starting']()
            obj.transitions['starting->started']()
            obj.transitions['started->focused']()
        end,
        ['starting->stopped'] = function()
            obj.transitions['starting->started']()
            obj.transitions['started->stopped']()
        end,
        ['starting->focused'] = function()
            obj.transitions['starting->started']()
            obj.transitions['started->focused']()
        end,
        ['focused->stopped'] = function()
            obj.transitions['focused->started']()
            obj.transitions['started->stopped']()
        end,
        -------------------------------------------
        ['init->starting'] = function()
            obj.log.f('Starting app [%s]', appName)
            obj.screen:background(ui.preview.thumbnail(obj.bundleID)):apply()
            obj.screen:hooks().onClick = function() end
            obj.state = 'starting'
        end,
        ['init->stopped'] = function()
            obj.log.f('App [%s] is stopped', appName)
            obj.screen:background(ui.preview.thumbnailS(obj.bundleID)):apply()
            obj.screen:hooks().onClick = function() hs.application.open(appName) end
            obj.state = 'stopped'
        end,
        ['starting->started'] = function()
            obj.log.f('App [%s] has started', appName)
            obj.screen:background(ui.preview.thumbnail(obj.bundleID)):apply()
            if #obj.hsApp:allWindows() then
                obj.screen:hooks().onClick = function() obj.hsApp:activate() end
            else
                obj.screen:hooks().onClick = function() hs.application.open(appName) end
            end
            obj.state = 'started'
        end,
        ['started->focused'] = function()
            obj.log.f('App [%s] has been focused', appName)
            obj.screen:focused(true):apply()
            obj.screen:hooks().onClick = function() end
            obj.cfg:event('focused')
            obj.state = 'focused'

            local autoLayout = (obj.cfg:get('layout') or hs.keycodes.layouts()[1])
            hs.keycodes.setLayout(autoLayout)
            local checkLayout = nil
            checkLayout = hs.timer.delayed.new(1, function()
                if not obj.hsApp:isFrontmost() then return end
                local currentLayout = hs.keycodes.currentLayout()
                if autoLayout ~= currentLayout then
                    obj.cfg:set('layout', currentLayout)
                    autoLayout = currentLayout
                end 
                checkLayout:start()
            end):start()
            obj.flowTime:start()
        end,
        ['started->stopped'] = function()
            obj.log.f('App [%s] has stopped', appName)
            obj.screen:background(ui.preview.thumbnailS(obj.bundleID)):apply()
            obj.screen:hooks().onClick = function() hs.application.open(appName) end
            obj.state = 'stopped'
            obj.flowTime:stop()
        end,
        ['focused->started'] = function()
            obj.log.f('App [%s] has lost focus', appName)
            if #obj.hsApp:allWindows() then
                obj.screen:hooks().onClick = function() obj.hsApp:activate() end
            else
                obj.screen:hooks().onClick = function() hs.application.open(appName) end
            end
            obj.screen:focused(false):apply()
            obj.state = 'started'
        end,
        ['stopped->starting'] = function()
            obj.log.f('App [%s] is restarting', appName)
            obj.screen:background(ui.preview.thumbnail(obj.bundleID)):apply()
            obj.screen:hooks().onClick = function() end
            obj.state = 'starting'
        end,
    }
    return obj
end

---@param status string
---@param appObject hs.application
function app:changeStatusTo(status, appObject)
    local transition = string.format('%s->%s', self.state, status)
    if self.transitions[transition] then
        self.transitions[transition]()
    else
        self.log.wf('Ignored transition [%s]', transition)
    end
    if appObject ~= nil then 
        self.hsApp = appObject
    end
    if self.cfg:get('locked') or (self.hsApp and #self.hsApp:allWindows() > 0) then
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
end

    -- self.snapshotter = hs.timer.doEvery(1, function()
    --     local w
    --     if #self.focusHist > 0 then
    --         w = self.focusHist[#self.focusHist]
    --     elseif #self.windows > 0 then
    --         w = self.windows[#self.windows]
    --     end
    --     if not w then return end
    --     if not self.screen then return end
    --     self.screen:background(w:snapshot(true)):apply()
    -- end)

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
-- obj     self.screen:background(ui.preview.thumbnail(obj.bundleID))
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
