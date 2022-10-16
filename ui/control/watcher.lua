hs.window.animationDuration = 0

---@class ui.control.appMgr
local appMgr = {}
appMgr.__index = appMgr
appMgr.__name = 'appMgr'
---@type hs.application.watcher
appMgr.__appTracker = nil
---@type hs.window.layout
appMgr.__layout = nil
---@type table<string, table>
appMgr.__exceptions = {
    ['Notification Center'] = {ignore=true},
    ['Mission Control'] = {ignore=true},
    ['Dock'] = {ignore=true},
    ['Hammerspoon'] = {ignore=true},
}

---@return ui.control.appMgr
function appMgr:new(views)
    ---@type ui.control.appMgr
    local o = {}
    setmetatable(o, self)

    o.__availableViews = {}
    o.__evictableViews = {}
    o.__lockedViews = {}
    o.__undistributed = {}
    o.log = hs.logger.new('appMgr', 'info')
    for i = 1, #views do
        o:register(views[i])
    end

    o.__appState = {}
    hs.fnutils.each(hs.application.runningApplications(), function(app)
        if (self.__exceptions[app:name()] or {}).ignore then return end
        o.__appState[app:name()] = o:onAppStart(app)
    end)

    ---@type hs.application.watcher
    o.__appTracker = hs.application.watcher.new(
        ---@param name string
        ---@param event string
        ---@param app hs.application
        function(name, event, app)
            if app == nil then return end
            if (self.__exceptions[appName] or {}).ignore then return end
            if event == hs.application.watcher.activated then end
            if event == hs.application.watcher.deactivated then end
            if event == hs.application.watcher.hidden then end
            if event == hs.application.watcher.launching then end
            if event == hs.application.watcher.launched then
                if o.__appState[app:name()] ~= nil then
                    o.__appState[app:name()].cleanup()
                    o.__appState[app:name()] = nil
                end
                o.__appState[app:name()] = o:onAppStart(app)
            end
            if event == hs.application.watcher.terminated then
                o.__appState[app:name()].cleanup()
                o.__appState[app:name()] = nil
            end
            if event == hs.application.watcher.unhidden then end
        end
    )

    local fallback = hs.window.filter.new(nil):setCurrentSpace(true)

    ---@param w hs.window
    local function customFilter(w)
        if w == nil then
            return false
        end
        ---@type hs.geometry
        local f, fScreen = w:frame(), hs.screen.mainScreen():fullFrame()
        if f.w < fScreen.w / 10 or f.h < fScreen.h / 10 or f.w * f.h < fScreen.w * fScreen.h / 20 then
            return false
        end
        ---@type hs.window.filter
        return fallback:isWindowAllowed(w)
    end

    ---@type hs.window.filter
    local layoutWindows = hs.window.filter.new(customFilter)
    layoutWindows = layoutWindows:setCurrentSpace(true):setDefaultFilter()
    o.__layout = hs.window.layout.new({
        { layoutWindows, 'move all foc [15,0,100,100] 0,0' },
    }, 'layout', 'warning')

    return o
end

---@param app hs.application
function appMgr:onAppStart(app)
        self.log.df("Tracking the app %s has started", app:name())
        ---@type hs.window.filter
        local __visibleWindows = hs.window.filter.new(false):setAppFilter(app:name(),{visible=true})
            :setSortOrder(hs.window.filter.sortByFocusedLast)
            :subscribe({ hs.window.filter.windowAllowed }, function(_w, appName, event)
            self:distribute(_w, appName)
        end)
        ---@type hs.window.filter
        local __managedWindows = hs.window.filter.new(false):setAppFilter(app:name(),{})
            :setSortOrder(hs.window.filter.sortByCreated)
            :subscribe({ hs.window.filter.windowRejected }, function(_w, appName, event)
        end)

        hs.fnutils.each(__visibleWindows:getWindows(), function(w)
            self:distribute(w, app:name())
        end)

        return {
            visibleWindows = __visibleWindows,
            managedWindows = __managedWindows,
            appName = app:name(),
            app = app,
            cleanup = function()
                __visibleWindows:pause()
                __managedWindows:pause()
                hs.fnutils.each(__managedWindows:getWindows(), function(w)
                    self:callback(w, app:name())
                end)
            end
        }
end

function appMgr:distribute(window, appName)
    ---@type ui.control.viewLink
    local view = nil
    if #self.__availableViews > 0 then
        view = table.remove(self.__availableViews, 1)
        view:attachToWindow(window)
        table.insert(self.__evictableViews, view)
        self.log.f('distribute: using view for window [%s]: %s', appName, window:title())
    elseif #self.__evictableViews > 0 then
        view = table.remove(self.__evictableViews, 1)
        view:detach()
        view:attachToWindow(window)
        self.log.f('distribute: reuse view for window [%s]: %s', appName, window:title())
    else
        table.insert(self.__undistributed, {window=window, appName=appName})
    end
    self:reorder()
end

function appMgr:callback(window, appName)
    self.log.f('callback: window [%s]: %s', appName, window:id())
    ---@type ui.control.viewLink
    local view = nil
    hs.fnutils.each(self.__lockedViews, function(view)
        if view:attachedTo(window, appName) then
            view:detach()
        end
    end)
    local toEvict = hs.fnutils.indexOf(self.__evictableViews, function(view)
        return view:attachedTo(window, appName)
    end)
    self.log.i('callback: view [', toEvict, '] is about to be evicted')
    if toEvict ~= nil and toEvict > 0 then
        ---@type ui.control.viewLink
        local view = self.__evictableViews[toEvict]
        table.remove(self.__evictableViews, toEvict)
        self.log.f('distribute: detaching view for window [%s]: %s', appName, window:title())
        view:detach()
        table.insert(__availableViews, view)
    end
    self:reorder()
end

---@return ui.control.appMgr
function appMgr:start()
    self.__appTracker:start()
    self.__layout:start()
    return self
end

---@return ui.control.appMgr
function appMgr:stop()
    self.__layout:stop()
    self.__appTracker:stop()
    return self
end

function appMgr:reorder()
    while true do
        self.log.f('reorder: available views before: %s', hs.inspect.inspect(
                hs.fnutils.map(self.__availableViews, function(v) return v.__id end))
        )
        table.sort(self.__availableViews, function(v1, v2) return v1.__id < v2.__id end)
        table.sort(self.__evictableViews, function(v1, v2) return v1.__id < v2.__id end)
        table.sort(self.__lockedViews, function(v1, v2) return v1.__id < v2.__id end)
        self.log.f('reorder: available views after: %s', hs.inspect.inspect(
                hs.fnutils.map(self.__availableViews, function(v) return v.__id end)
        ))
        local available = self.__availableViews[1]
        local evictable = self.__evictableViews[#self.__evictableViews]
        if available == nil or evictable == nil then break end
        if available.__id > evictable.__id then break end
        self.log.f('reorder: swapping view %s with %s', available.__id, evictable.__id)
        local window, appName = evictable.__window, evictable.__appName
        evictable:detach()
        available:attachToWindow(window, appName)

        table.remove(self.__availableViews, 1)
        table.remove(self.__evictableViews, #self.__evictableViews)
        table.insert(self.__evictableViews, available)
    end
    self.log.f('reorder: available views finally: %s', hs.inspect.inspect(
            hs.fnutils.map(self.__availableViews, function(v) return v.__id end)
    ))
end

---@param view ui.preview.window
---@return ui.control.appMgr
function appMgr:register(view)
    self.__viewId = (self.__viewId or 0) + 1
    table.insert(self.__availableViews, ui.control.viewLink:new(view, function(link)
        local evictIdx = hs.fnutils.indexOf(self.__evictableViews, link)
        if evictIdx then
            table.remove(self.__evictableViews, evictIdx)
            table.insert(self.__availableViews, link)
            self:reorder()
            return
        end
        local unlockIdx = hs.fnutils.indexOf(self.__lockedViews, link)
        if unlockIdx then
            table.remove(self.__lockedViews, unlockIdx)
            table.insert(self.__availableViews, link)
            self:reorder()
            return
        end
    end))

    return self
end

return appMgr
