---@class ui.control.broker
---@field private __bbcLife hs.application.watcher
---@field private __bbcWorld hs.window.filter
---@field private __focused hs.window
---@field private __focusedApp ui.control.app
---@field private __units table<string, ui.control.app>
---@field private __layout ui.control.layout
---@field private __enforcer hs.timer.delayed
---@field private __toProcess fun()[]
local broker = {}
broker.__index = broker
broker.__name = 'ui.control.launcher'
broker.__layoutAutoChanged = nil


---@return ui.control.broker
function broker:new()
    local obj = {}
    setmetatable(obj, broker)
    obj.__units = {}
    obj.__bbcWorld = hs.window.filter.new(nil, 'BB', 'info')

    obj.__layout = ui.control.layout:new(8)
    obj.__bbcLife = hs.application.watcher.new(ui.fn.partial(obj.processAppEvent, obj))
    obj.__toProcess = {}
    obj.__enforcer = hs.timer.doEvery(1, function()
        obj.__layout:reorder()
    end)
    return obj
end

---@return ui.control.broker
function broker:start()
    for _, app in pairs(hs.application.runningApplications()) do
        if app:kind() == 1 then
            self:processAppEvent(app:title(), hs.application.watcher.launched, app)
        end
    end
    self.__bbcLife:start()
    local f = self.__layout.workspace:toUnitRect(ui.desktop):fromUnitRect(ui.screen)
    local rule = string.format('mov all foc [%d,%d,%d,%d] 0,0',
        math.ceil(f.x * 100 / ui.screen.w),
        math.ceil(f.y * 100 / ui.screen.h),
        math.ceil((f.x + f.w) * 100 / ui.screen.w),
        math.ceil((f.y + f.h) * 100 / ui.screen.h)
    )


    hs.window.layout.new({
        { self.__bbcWorld, rule },

    },'bbcworld', 'info'):start()
    -- self.__bbcWorld:subscribe(hs.window.filter.windowFocused, function(w, appName)
    --     table.insert(self.__toProcess, ui.fn.partial(self.onFocusEvent, self, w, appName))
    -- end)
    -- self.__bbcWorld:subscribe({hs.window.filter.windowDestroyed}, function(w, appName, event)
    --     self:onWindowClose(w, appName)
    -- end, true)
    self.__enforcer:start()
    self:enableHotkeys()
    return self
end

---@param appName string
---@param eventType any
---@param appObject hs.application
function broker:processAppEvent(appName, eventType, appObject)
    if appName == nil then
        return
    end
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
            -- if e:getKeyCode() == 12 and e:getFlags()['alt'] then
            --     self.__focusedApp:hide()
            --     return true
            -- end
            -- if e:getKeyCode() == 13 and e:getFlags()['alt'] then
            --     self.__focusedApp:focusedWindow():minimize()
            --     return true
            -- end
            if e:getKeyCode() == 31 and e:getFlags()['alt'] then
                hs.eventtap.keyStroke({ 'cmd' }, 'space')
                return true
            end
            if e:getKeyCode() == 15 and e:getFlags()['alt'] then
                hs.reload()
                return true
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
