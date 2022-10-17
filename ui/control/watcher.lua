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
    ['Spotlight'] = {ignore=true},
    ['Finder'] = {ignore=true},
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

    local fallback = hs.window.filter.default

    ---@param w hs.window.filter
    o.customFilter = hs.window.filter.new(function(w)
        if w == nil or w:id() == 0 then
            return false
        end

        ---@type hs.geometry
        local f, fScreen = w:frame(), hs.screen.mainScreen():fullFrame()
        if (f.w < fScreen.w / 10) or (f.h < fScreen.h / 10) then
            return false
        end
        return fallback:isWindowAllowed(w)
    end):setSortOrder(hs.window.filter.sortByFocused):subscribe({hs.window.filter.windowAllowed}, function(window, appName, event)
        o:distribute(window, appName)
    end):setSortOrder(hs.window.filter.sortByFocused):subscribe({hs.window.filter.windowRejected}, function(window, appName, event)
        o:callback(window, appName)
    end)

    o.log = hs.logger.new('appMgr', 'warning')
    for i = 1, #views do
        o:register(views[i])
    end

    o.__appState = {}
    o:keyboardHandler()

    ---@type hs.window.filter
    local layoutWindows = hs.window.filter.copy(o.customFilter)
    layoutWindows = layoutWindows:setCurrentSpace(true):setDefaultFilter()
    o.__layout = hs.window.layout.new({
        { layoutWindows, 'move all foc [15,0,100,100] 0,0' },
    }, 'layout', 'warning')

    return o
end

function appMgr:keyboardHandler()
    hs.keycodes.inputSourceChanged( function()
        local newMethod = hs.keycodes.currentLayout()
        local app = hs.application.frontmostApplication()
        local window = app:focusedWindow()

        hs.fnutils.each(
            hs.fnutils.concat(self.__evictableViews, self.__lockedViews), function(v)
                if v:attachedToWindow(window) then
                    if v:getLayoutMethod() ~= newMethod then
                        v:setLayoutMethod(newMethod)
                    end
                end
            end
        )

        self.log.f('input source changed to %s for app %s', newMethod, app:name())
    end)

    self.__events = hs.eventtap.new({
        hs.eventtap.event.types.keyDown,
        hs.eventtap.event.types.flagsChanged
    }, function(e)
        if e:getKeyCode() == 12 and e:getFlags()['alt'] then
            hs.application.frontmostApplication():hide()
            return true
        end
        if e:getKeyCode() == 13 and e:getFlags()['alt'] then
            hs.application.frontmostApplication():focusedWindow():minimize()
            return true
        end
        if e:getKeyCode() == 31 and e:getFlags()['alt'] then
            hs.eventtap.keyStroke({'cmd'}, 'space')
            return true
        end
        if e:getKeyCode() == 15 and e:getFlags()['alt'] then
            hs.reload()
            return true
        end
        if e:getFlags()['alt'] and  (e:getKeyCode() >= hs.keycodes.map['1'] and e:getKeyCode() <= hs.keycodes.map['9']) then
            local __viewId = e:getKeyCode() - hs.keycodes.map['1'] + 1
            hs.fnutils.each(
                hs.fnutils.concat(self.__evictableViews, self.__lockedViews), function(v)
                    if v.__id == __viewId  then
                        hs.console.printStyledtext(v.__name .. ' ' .. tostring(v.__id))
                        v:activate()
                    end
                end
            )
            return false
        end
        return false

        --if e:getKeyCode() == 48 and e:getFlags()['alt'] then
        --    if self.__alttab == nil then
        --        self.__alttab = {
        --            index = -2
        --        }
        --    end
        --    for i = 1, #self.__registered do
        --        self.__alttab.index = self.__alttab.index + 1
        --        if self.__alttab.index < 1 then
        --            if self:back(self.__alttab.index + 2) then
        --                return true
        --            end
        --        else
        --            local activePreviews = hs.fnutils.filter(self.__registered, function(v)
        --                return v:linkedTo() ~= nil
        --            end)
        --            activePreviews[self.__alttab.index % #activePreviews + 1]:activate()
        --            return true
        --        end
        --    end
        --    return true
        --end
    end)
end


function appMgr:distribute(window, appName)
    ---@type ui.control.viewLink
    local view = nil
    if #self.__availableViews > 0 then
        view = self.__availableViews[1]
        view:attachToWindow(window)
        self.log.f('distribute: using view for window [%s]: %s', appName, window:title())
        self:reorder()
        return
    end
    if #self.__evictableViews > 0 then
        view = self.__evictableViews[1]
        view:detach()
        view:attachToWindow(window, appName)
        self.log.f('distribute: reuse view for window [%s]: %s', appName, window:title())
        self:reorder()
    else
        table.insert(self.__undistributed, {window=window, appName=appName})
    end
end

function appMgr:callback(window, appName)
    self.log.f('callback: window [%s]: %s', appName, window:id())

    ---@type ui.control.viewLink
    local view = nil
    local views = hs.fnutils.filter(hs.fnutils.concat(self.__evictableViews, self.__lockedViews), function(v)
        return v:attachedToWindow(window)
    end)
    hs.fnutils.each(views, function(v)
        v:detach()
    end)
    self.__undistributed = hs.fnutils.filter(self.__undistributed, function(_view)
        return not _view:attachedToWindow(window)
    end)
    self:reorder()
end

---@return ui.control.appMgr
function appMgr:start()
    self.__layout:start()
    self.__events:start()
    hs.fnutils.each(self.customFilter:getWindows(), function(w)
        self:distribute(w, w:application():name())
    end)
    return self
end

---@return ui.control.appMgr
function appMgr:stop()
    self.__events:stop()
    self.__layout:stop()
    return self
end

function appMgr:reorder()
    table.sort(self.__lockedViews, function(v1, v2) return v1.__id < v2.__id end)
    for i = 1, #self.__lockedViews do
        local lockedView = self.__lockedViews[i]
        if lockedView.__id ~= i then
            hs.fnutils.each(self.__availableViews, function(v)
                if v.__id == i then
                    v:swap(lockedView)
                end
            end)
            hs.fnutils.each(self.__evictableViews, function(v)
                if v.__id == i then
                    v:swap(lockedView)
                end
            end)
        end
        hs.fnutils.each(self.__evictableViews, function(v)
            local state = v:attachmentInfo()
            if not lockedView:attachedToWindow() then
                if state.toWindow and state.appName == lockedView.__app:name() then
                    v:detach()
                    lockedView:attachTo(state)
                end
            end
        end)
    end

    table.sort(self.__availableViews, function(v1, v2) return v1.__id < v2.__id end)
    table.sort(self.__evictableViews, function(v1, v2) return v1.__id < v2.__id end)
    for i = 1, #self.__availableViews do
        local availableView = self.__availableViews[i]
        hs.fnutils.each(self.__evictableViews, function(v)
            if v.__id > availableView.__id then
                v:swap(availableView)
            end
        end)
    end

    self:dump()

    self.log.f('reorder: available views finally: %s', hs.inspect.inspect(
            hs.fnutils.map(self.__availableViews, function(v) return v.__id end)
    ))
end

---@param view ui.preview.window
---@return ui.control.appMgr
function appMgr:register(view)
    self.__viewId = (self.__viewId or 0) + 1
    local link = ui.control.viewLink:new(view,
            self.customFilter,
        function(link)
            local availIdx = hs.fnutils.indexOf(self.__availableViews, link)
            if availIdx then
                table.remove(self.__availableViews, availIdx)
                table.insert(self.__evictableViews, link)
                self:reorder()
                return
            end
        end,
        function(link)
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
        end,
        function(link)
            local availIdx = hs.fnutils.indexOf(self.__availableViews, link)
            if availIdx then
                table.remove(self.__availableViews, availIdx)
                table.insert(self.__lockedViews, link)
                self:reorder()
                return
            end
            local evictIdx = hs.fnutils.indexOf(self.__evictableViews, link)
            if evictIdx then
                table.remove(self.__evictableViews, evictIdx)
                table.insert(self.__lockedViews, link)
                self:reorder()
                return
            end
        end,
        function(link)
            local lockIdx = hs.fnutils.indexOf(self.__lockedViews, link)
            if lockIdx then
                table.remove(self.__lockedViews, lockIdx)
                if link.__window ~= nil and link.__window:id() ~= nil then
                    table.insert(self.__evictableViews, link)
                else
                    table.insert(self.__availableViews, link)
                end
                self:reorder()
                return
            end
        end)
    table.insert(self.__availableViews, link)
    return self
end

function appMgr:dump()
    local state = {
        availableViews = hs.fnutils.map(self.__availableViews, function(v) return v:attachmentInfo() end),
        evictableViews = hs.fnutils.map(self.__evictableViews, function(v) return v:attachmentInfo() end),
        lockedViews = hs.fnutils.map(self.__lockedViews, function(v) return v:attachmentInfo() end),
    }
    hs.json.write(state, hs.configdir .. '/state.json', true, true)
end

function appMgr:restore()
    local state = hs.json.read(state, hs.configdir .. '/state.json', true, true)

end


return appMgr
