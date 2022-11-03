---@class ui.control.broker
---@field private __bbcLife hs.application.watcher
---@field private __bbcWorld hs.window.filter
---@field private __bbcNew hs.window.filter
---@field private __focused hs.window
---@field private __focusedApp ui.control.app
---@field private __units table<string, ui.control.app>
---@field private __layout ui.control.layout
---@field private __toProcess fun()[]
---@field private __gotoApp hs.hotkey
local broker = {}
broker.__index = broker
broker.__name = 'ui.control.launcher'
broker.__layoutAutoChanged = nil
hs.window.layout.applyDelay = 0


---@return ui.control.broker
function broker:new()
    local obj = {}
    setmetatable(obj, broker)
    obj:enableHotkeys()
    obj.__units = {}
    obj.__bbcWorld = hs.window.filter.new(nil, 'BB', 'warning'):rejectApp('Hammerspoon'):rejectApp('Finder')
    obj.__layout = ui.control.layout:new(8)
    obj.__bbcLife = hs.application.watcher.new(ui.fn.partial(obj.processAppEvent, obj))
    obj.__bbcNew = hs.window.filter.new(
        ---@param w hs.window
        function(w)
            if w == nil then return false end
            if w:isMinimized() then return false end
            if w:isMaximizable() then return false end
            if w:subrole() == 'AXSystemDialog.Hammerspoon' then return true end
            if w:application():title() == 'Finder' then return true end

            ---@type hs.geometry
            local size = w:frame()
            if size.h == 0 and size.w == 0 then
                return false
            end
            size.h = size.h / ui.screen.h
            size.w = size.w / ui.screen.w
            if size.h * size.w < 0.1 then
                return true
            end
        end)

    obj.__toProcess = {}
    obj.__enforcerCtx = {
        numUnits = 0
    }
    return obj
end

---@return ui.control.broker
function broker:start()
    self.__bbcLife:start()
    for _, app in pairs(hs.application.runningApplications()) do
        if app:kind() == 1 then
            self:processAppEvent(app:title(), hs.application.watcher.launched, app)
            for _, w in ipairs(app:allWindows()) do
                self:processWindowEvent(app:title(), hs.window.filter.windowAllowed, w)
            end
        end
    end

    self.__bbcWorld:subscribe({
        hs.window.filter.windowFocused, hs.window.filter.windowUnfocused,
        hs.window.filter.windowAllowed, hs.window.filter.windowRejected,
    }, function(w, appName, event)
        self:processWindowEvent(appName, event, w)
    end)

    local f = self.__layout.workspace:toUnitRect(ui.desktop):fromUnitRect(ui.screen)
    local rect = {
        math.ceil(f.x * 100 / ui.screen.w),
        math.ceil(f.y * 100 / ui.screen.h),
        math.ceil((f.x + f.w) * 100 / ui.screen.w),
        math.ceil((f.y + f.h) * 100 / ui.screen.h)
    }

    local rule = string.format('mov 1 foc [%d,%d,%d,%d] 0,0', table.unpack(rect))
    local rule2 = string.format('mov all foc [%d,%d,%d,%d] 0,0', table.unpack(rect))


    hs.window.layout.new({
        { self.__bbcNew, 'noaction' },
        { self.__bbcWorld, rule .. '|' .. rule2 },
    }, 'bbcworld', 'warning'):apply()


    self.__bbcWorld:subscribe({hs.window.filter.windowRejected}, function(w, appName, event)
        self:onWindowClose(w, appName)
    end, true)
    return self
end

---@param appName string
---@param eventType any
---@param appObject hs.application
---@return ui.control.app | nil
function broker:processAppEvent(appName, eventType, appObject)
    local blockList = {['Hammerspoon']=true, ['Finder']=true}
    if appName == nil or blockList[appName] then return nil end
    if eventType == hs.application.watcher.terminated then
        for name, app in pairs(self.__units) do
            if app.hsApp:pid() == appObject:pid() then
                app:changeStatusTo('stopped', appObject)
                break
            end
        end
        return
    end

    if self.__units[appName] == nil then
        self.__units[appName] = ui.control.app:new(appName, self.__layout, appObject)
    end

    ---@type ui.control.app
    local app = self.__units[appName]

    if eventType == hs.application.watcher.launching then app:changeStatusTo('starting', appObject) end
    if eventType == hs.application.watcher.launched then app:changeStatusTo('started', appObject) end
    if eventType == hs.application.watcher.deactivated then app:changeStatusTo('started', appObject) end
    if eventType == hs.application.watcher.activated then app:changeStatusTo('focused', appObject) end

    return app
end

---@param eventType any
---@param windowObject hs.window
function broker:processWindowEvent(appName, eventType, windowObject)
    if windowObject.role == 'AXScrollArea' then return end

    ---@type hs.application | nil
    local appObject = windowObject:application()
    if appObject == nil then
        appObject = hs.application.get(appName)
    end

    if eventType == hs.window.filter.windowRejected then
        self:processAppEvent(appName, hs.application.watcher.deactivated, appObject):deregisterWindow(windowObject)
        return
    end

    if eventType == hs.window.filter.windowAllowed then
        self:processAppEvent(appName, hs.application.watcher.launched, appObject):registerWindow(windowObject)
    end

    if eventType == hs.window.filter.windowFocused then
        self:processAppEvent(appName, hs.application.watcher.focused, appObject):focusWindow(windowObject)
    end
end



-- ---@param w hs.window
-- ---@param appName string
-- function broker:onFocusEvent(w, appName)
--     w:setFrame(self.__layout.workspace:floor())

--     if self.__units[appName] == nil then
--         self.__units[appName] = ui.control.app:new(appName, self.__layout)
--     end

--     if self.__focusedApp ~= appName then
--         if self.__units[self.__focusedApp] ~= nil then
--             self.__units[self.__focusedApp]:onFocusLost()
--         end
--         self.__units[appName]:onFocus()
--     end

--     self.__focused = w
--     self.__focusedApp = appName

--     coroutine.applicationYield()

--     local cfg = require('ui.config'):new(appName)
--     local keyboardLayout = cfg:get('layout') or hs.keycodes.layouts()[1]
--     if keyboardLayout ~= hs.keycodes.currentLayout() then
--         self.__layoutAutoChanged = keyboardLayout
--         hs.keycodes.setLayout(keyboardLayout)
--     end
-- end

-- ---@param w hs.window
-- ---@param appName string
-- function broker:onWindowOpen(w, appName)
--     if self.__units[appName] == nil then
--         self.__units[appName] = ui.control.app:new(appName, self.__layout)
--     end
--     self.__units[appName]:onWindowOpen(w)
-- end

-- ---@param w hs.window
-- ---@param appName string
-- function broker:onWindowClose(w, appName)
--     if self.__units[appName] == nil then
--         self.__units[appName] = ui.control.app:new(appName, self.__layout)
--     end
--     self.__units[appName]:onWindowClose(w)
-- end


---@return ui.control.broker
function broker:enableHotkeys()
    self.__events = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.flagsChanged },
        function(e)
            if e:getKeyCode() == 31 and e:getFlags()['alt'] then
                hs.eventtap.keyStroke({ 'cmd' }, 'space')
                return true
            end
            if e:getKeyCode() == 15 and e:getFlags()['alt'] then
                hs.reload()
                return true
            end

            local focused
            for _, app in ipairs(self.__units) do
                if app.state == 'focused' then
                    focused = app
                    break
                end
            end
            if focused then
                if e:getKeyCode() == 12 and e:getFlags()['alt'] then
                    focused.hsApp:hide()
                    return true
                end
            end
            if hs.window.focusedWindow() then
                if e:getKeyCode() == 13 and e:getFlags()['alt'] then
                    hs.window.focusedWindow():minimize()
                    return true
                end
            end
            -- if e:getFlags()['alt'] and  (e:getKeyCode() >= hs.keycodes.map['1'] and e:getKeyCode() <= hs.keycodes.map['9']) then

            --    local __viewId = e:getKeyCode() - hs.keycodes.map['1'] + 1
            --    hs.fnutils.each(
            --            hs.fnutils.concat(self.__evictableViews, self.__lockedViews), function(v)
            --                if v.__id == __viewId  then
            --                    hs.console.printStyledtext(v.__name .. ' ' .. tostring(v.__id))
            --                    v:activate()
            --                end
            --            end
            --    )
            --    return false
            -- end
            return false
        end):start()
    return self
end

return broker
