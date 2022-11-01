local events = require 'ui.preview.events'

---@diagnostic disable: need-check-nil
hs.application.enableSpotlightForNameSearches(false)

function _(...)
    for i, v in ipairs({...}) do
        hs.console.printStyledtext(hs.inspect.inspect(v))
    end
end

local function inspect(info)
    return hs.inspect.inspect(info)
end

hs.loadSpoon('SpoonInstall', true)

-- spoon.SpoonInstall:andUse('ReloadConfiguration', {
--     config = {
--         watch_paths = { os.getenv('HOME') .. '/.hammerspoon' },
--         log_level = 'true',
--     },
--     start = false,
-- })
-- spoon.ReloadConfiguration.watch_paths = { os.getenv('HOME') .. '/.hammerspoon' }
-- spoon.SpoonInstall:andUse('EmmyLua')

-- local layoutApplicable = hs.window.filter.new(true)
-- layoutApplicable:subscribe(hs.window.filter.windowFocused, function(window, name, event)
--     local layout = hs.keycodes.currentLayout()
--     local target = 'U.S.'
--     if name == 'Texty' then
--         target = 'Russian'
--     end
--     if not layout == target then
--         hs.keycodes.setMethod(target)
--     end
--     -- print(window:title(), name, layout, target, hs.keycodes.currentLayout())
-- end)


-- k = hs.hotkey.modal.new('cmd-shift', 'd')
-- function k:entered() hs.alert 'Entered mode' end
-- function k:exited() hs.alert 'Exited mode' end
-- k:bind('', 'escape', function() k:exit() end)
-- k:bind('', 'J', 'Pressed J', function() print 'let the record show that J was pressed' end)



-- hs.loadSpoon("FocusHighlight")
-- spoon.FocusHighlight:start()
-- spoon.FocusHighlight.color = "#546E7A"
-- spoon.FocusHighlight.windowFilter = hs.window.filter.new(true)
-- spoon.FocusHighlight.arrowSize = 256
-- spoon.FocusHighlight.arrowFadeOutDuration = 3
-- spoon.FocusHighlight.highlightFadeOutDuration = 2
-- spoon.FocusHighlight.highlightFillAlpha = 0.4
-- hs.pasteboard.writeObjects(hs.screen.mainScreen():snapshot())

-- hs.grid.setGrid('120x120')
-- hs.grid.ui.textSize = 100

-- bind to hotkeys; WARNING: at least one modifier key is required!
-- hs.hotkey.bind('ctrl', 'tab', 'Next window', function() switcher_space:next() end)

local filler = hs.canvas.new({ x = 0, y = 0, w = 125, h = 100 }):appendElements({
    type = "rectangle",
    action = "fill",
    fillColor = { white = 0.1, alpha = 0.3 },
    frame = { x = "0%", y = "0%", h = "100%", w = "100%" },
}):imageFromCanvas()

local function stalk(c, duration)
    if c == nil then return end
    hs.canvas.new(c:frame()):appendElements({
        type = 'image', image = c:imageFromCanvas()
    }):show():delete(duration)
end


local history = function ()
    local last_visit = {}
    local w = require 'hs.window'
    local snap = w.snapshotForID

    local function capture_info(window)
        local window_info = {
            window_id = window:id(),
            window_title = window:title(),
            thumbnail = snap(window:id()),
        }
        local app_info = {
            id = window:application():bundleID(),
            name = window:application():name(),
            path = window:application():path(),
        }

    end

    return {
        visit = function(window)
            if window == nil then return end
            last_visit = {
                window_id = window:id(),
                window_title = window:title(),
                app = {
                    id = window:application():bundleID(),
                    name = window:application():name(),
                    path = window:application():path(),
                    thumbnail = window:application():frontmostWindow():snapshot(),
                },
                thumbnail = window:snapshot(),

            }
        end
    }
end

local function sortByTitle(windows)
    local fn = function(w)
        if w == nil then
            return nil
        end
        if w:application() == nil then
            return w:title()
        end
        return w:application():title()
    end
    local cmpByTitle = function(l, r) return (fn(l) < fn(r)) end
    return hs.fnutils.sortByKeyValues(windows, cmpByTitle)
end

local function PreviewWindow()

end

local function AppTracker()
    if AppTrackerCtx == nil then
        AppTrackerCtx = {}
        AppTrackerCtx.new = function() return AppTracker():new() end
        hs.application.watcher.new(function (name, event, app)
            if event == hs.application.watcher.activated then end
            if event == hs.application.watcher.deactivated then end
            if event == hs.application.watcher.hidden then end
            if event == hs.application.watcher.launching then end
            if event == hs.application.watcher.launched then end
            if event == hs.application.watcher.terminated then end
            if event == hs.application.watcher.unhidden then end
        end):start()
        AppTrackerCtx.coengine = coroutine.wrap(function ()
            while true do
            end
        end)
    end

    ---@class appTracker
    local app = {}
    app.__index = app
    app.__name = 'app'
    app.__bundleID = nil

    function app:new(bundleID)
        local self = {}
        setmetatable(self, app)
        self.__bundleID = bundleID
        return self
    end

    function app:snapshotStub()
        hs.fs.mkdir(hs.configdir .. '/cache')
        local snapshotFile = hs.configdir .. '/cache/' .. app.__bundleID .. '.png'
        local oldSnapshot = hs.image.imageFromPath(snapshotFile)
        if oldSnapshot then return oldSnapshot end

        local frame = hs.screen.mainScreen():frame()
        local tmpImg = hs.canvas.new(frame):appendElements({
            type = 'image',
            image = hs.image.imageFromAppBundle(app.__bundleID),
            imageAlignment = 'left',
            imageAlpha = 1,
            padding = frame.h * 0.05,
            imageScaling = 'scaleToFit',
        }, {
            type = "rectangle",
            action = "fill",
            fillGradientColors = {
                { hex = "#37474F", alpha = 0.7 },
                { hex = "#263238", alpha = 0.6 },

            }, fillGradient = "radial"
        }
        ):imageFromCanvas():resize(frame.w * 0.2, frame.h * 0.2)
        if tmpImg then
            tmpImg:saveToFile(snapshotFile)
            return tmpImg
        end
    end

    function app:activate()
        hs.application.launchOrFocusByBundleID(app.__bundleID)
    end

    return app
end

--local function preview(grp)
--    ---@class preview
--    local self = {}
--    self.__index = self
--    self.__name = 'self'
--    self.dNdContext = {}
--    self.id = grp:next()
--
--    ---@type hs.window
--    self.window = nil
--
--    ---@type hs.canvas
--    self.canvas = nil
--
--    ---@type lockpad
--    self.lockpad = lockpad()
--
--    ---@type hs.axuielement.observer
--    self.focusGuard = nil
--
--    self.appCtx = {
--        preferredLayout = nil
--    }
--
--
--
--
--    function self:join(w)
--        if self.lockpad.locked and not w:application():bundleID() == self.bundleID then
--            return nil, 'locked'
--        end
--
--        if w == nil then
--            return nil, 'nil'
--        end
--
--        if w and self.window and self.window:id() == w:id() then
--            return nil, 'same'
--        end
--
--        if not w or not w:application() or not w:application():bundleID() then
--            return nil, 'empty'
--        end
--
--        if self.window ~= nil then
--            self:clear()
--        end
--        self.window = w
--        self.bundleID = w:application():bundleID()
--        self.filter = hs.window.filter.new(
--            function(_w)
--                return self.window ~= nil and _w ~= nil and _w:id() == self.window:id()
--            end,
--            'preview:' .. self.id
--        ):subscribe(
--            { hs.window.filter.windowFocused },
--            function(_w, appName, event)
--                self.window = _w
--                self:focus(true)
--                if self.focusGuard then
--                    self.focusGuard:addWatcher(hs.axuielement.windowElement(_w),
--                        hs.axuielement.observer.notifications.focusedUIElementChanged
--                    )
--                end
--            end,
--            true
--        ):subscribe(
--            { hs.window.filter.windowUnfocused },
--            function(_w, appName, event)
--                self:focus(false)
--            end,
--            true
--        ):subscribe(
--            { hs.window.filter.windowRejected },
--            function(_w, appName, event)
--                self:clear()
--            end,
--            true
--        )
--        self.focusedElement = nil
--        self.focusGuard = hs.axuielement.observer.new(w:application():pid()):start()
--        self.focusGuard:callback(function(observer, element, event)
--            print(event)
--            if event == hs.axuielement.observer.notifications.focusedUIElementChanged then
--                self.focusedElement = element
--                self.appCtx.focusedElement = hs.axuielement.path(element)
--            end
--        end)
--
--
--
--        self.appCtx.preferredLayout = self.appCtx.preferredLayout or hs.keycodes.layouts()[1]
--
--        self.snapshotter = hs.timer.delayed.new(hs.math.randomFloat()*0.2 + 1.0, function()
--            self.snapshotter:start()
--            self:snapshot()
--        end):start()
--
--        grp:onLink(self)
--        self.canvas:show(1)
--        return self
--    end
--
--    function self:clear()
--        local state
--        if self.lockpad.locked then
--            state = self:dump()
--        end
--
--        if self.filter then
--            self.filter:unsubscribeAll()
--            self.filter = nil
--        end
--        self.window = nil
--        self.bundleID = nil
--        self.focused = false
--        if self.snapshotter then
--            self.snapshotter:stop()
--        end
--        self.focusGuard:stop()
--        self.canvas:elementAttribute(1, 'image', filler)
--        self.canvas:elementAttribute(1, 'imageAlignment', 'left')
--        self.appCtx = {
--            preferredLayout = nil
--        }
--
--        if state ~= nil then
--            self:restore(state.linkedTo.bundleID, state.appCtx)
--        else
--            self.canvas:elementAttribute(1, 'image', filler)
--        end
--        grp:onClear(self)
--        return self
--
--    end
--
--    function self:snapshot()
--        if self.window == nil then
--            return
--        end
--        local snapshot = self.window:snapshot()
--        if snapshot == nil then return end
--        if hs.window.focusedWindow() and hs.window.focusedWindow():id() == self.window:id() then
--            self.appCtx.preferredLayout = hs.keycodes.currentLayout()
--        end
--        self.canvas:elementAttribute(1, 'image', snapshot)
--        if not self.oldSnapshot and self.snapshotFile then
--            snapshot:setSize({ h = 768, w = 1024 }):saveToFile(self.snapshotFile)
--            self.oldSnapshot = true
--        end
--
--        collectgarbage('step')
--        return snapshot
--    end
--
--
--    function self:linkedTo()
--        return self.window
--    end
--
--    function self:focus(status)
--        self.focused = status
--        if self.focused or self.lockpad.locked then
--            self.canvas:elementAttribute(1, 'imageAlignment', 'right')
--        end
--        if not self.focused and not self.lockpad.locked then
--            self.canvas:elementAttribute(1, 'imageAlignment', 'left')
--        end
--        if self.focused then
--            hs.keycodes.setLayout(self.appCtx.preferredLayout or hs.keycodes.layouts()[1])
--            grp:onFocus(self)
--        end
--
--        return self
--    end
--
--    function self:lock()
--        self:focus(true)
--    end
--
--    function self:unlock()
--        self:focus(false)
--    end
--
--    function self:show()
--        self.canvas:show()
--        return self
--    end
--
--    function self:hide()
--        self.canvas:hide()
--        return self
--    end
--
--    function self:activate()
--        if self.bundleID == nil then
--            return
--        end
--        if self.window and hs.window.find(self.window:id()) then
--            self.window:focus()
--            if self.focusedElement then
--                self.focusedElement:setAttributeValue("AXFocused", true)
--            end
--
--        else
--            hs.application.open(self.bundleID)
--        end
--        self:focus(true)
--        return self
--    end
--
--    function self:dump()
--        return {
--            id = self.id,
--            linkedTo = {
--                id = self.window and self.window:id(),
--                title = self.window and self.window:title(),
--                bundleID = self.bundleID or (self.window and self.window:application() and self.window:application():bundleID()),
--            },
--            appCtx = self.appCtx,
--            preferredLayout = self.appCtx.preferredLayout,
--        }
--    end
--
--    function self:restore(bundleID, appCtx)
--        self.lockpad:lock()
--        self.bundleID = bundleID
--        self:dummySnapshot()
--        self:activate()
--        if appCtx == nil then appCtx = self.appCtx end
--        self.appCtx = appCtx
--        self.appCtx.preferredLayout = self.appCtx.preferredLayout or hs.keycodes.layouts()[1]
--    end
--
--    function self:swap(other)
--        self.id, other.id = other.id, self.id
--        local localFrame = hs.geometry.copy(self.canvas:frame())
--        local otherFrame = hs.geometry.copy(other.canvas:frame())
--        self.canvas:frame(otherFrame)
--        self.lockpad.canvas:frame(self.canvas:frame())
--        other.canvas:frame(localFrame)
--        other.lockpad.canvas:frame(other.canvas:frame())
--    end
--
--
--    return self
--end

-- local function previewGroup()
--     ---@class PreviewGroup
--     local self = {}

--     self.__index = self
--     self.__name = 'self'
--     self.__items = 0

--     ---@type preview[]
--     self.__registered = {}

--     ---@type preview[]
--     self.__history = {}

--     ---@type preview
--     self.__focus = {}

--     self.__alttab = nil
--     self.__recoverState = {}

--     function self:next()
--         self.__items = self.__items + 1
--         return self.__items
--     end

--     function self:init(frame)
--         local bgRect = hs.geometry.new({ x = 0, y = 0, h = frame.h, w = frame.w }):floor()
--         self.bg = hs.canvas.new(bgRect):appendElements({
--             type = "image",
--             action = "fill",
--             image = hs.image.imageFromURL("file:///Users/ibiin/.hammerspoon/bg.png"),
--             imageScaling = "scaleToFit",
--             imageAlpha = 0.7,
--             compositeRule = 'plusDarker',
--         }):level(hs.canvas.windowLevels.desktopIcon)
--         self.hidden = true
--         self.__events = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.flagsChanged }, function(e)
--             if e:getKeyCode() == 12 and e:getFlags()['alt'] then
--                 self.__current_focus:linkedTo():application():hide()
--                 return true
--             end
--             if e:getKeyCode() == 13 and e:getFlags()['alt'] then
--                 local app = self.__current_focus:linkedTo():application()
--                 app:hide()
--                 return true
--             end
--             if e:getKeyCode() == 31 and e:getFlags()['alt'] then
--                 hs.application.open("Alfred 4")
--                 return true
--             end
--             for i = 1, #self.__registered do
--                 if i == 10 then break end
--                 if e:getKeyCode() == hs.keycodes.map[tostring(i)] and e:getFlags()['alt'] then
--                     self.__registered[i]:activate()
--                     return true
--                 end
--             end
--             if e:getKeyCode() == 48 and e:getFlags()['alt'] then
--                 if self.__alttab == nil then
--                     self.__alttab = {
--                         index = -2
--                     }
--                 end
--                 for i=1,#self.__registered do
--                     self.__alttab.index = self.__alttab.index + 1
--                     if self.__alttab.index < 1 then
--                         if self:back(self.__alttab.index + 2)then
--                             return true
--                         end
--                     else
--                         local activePreviews = hs.fnutils.filter(self.__registered, function(v)
--                             return v:linkedTo() ~= nil
--                         end)
--                         activePreviews[self.__alttab.index % #activePreviews + 1]:activate()
--                         return true
--                     end
--                 end
--                 return true
--             end
--             self.__alttab = nil
--         end)
--         local state = hs.json.read(hs.configdir .. '/preview.json')
--         if state then
--             for _, v in ipairs(state) do
--                 self.__recoverState[v.id] = function(preview)
--                     local ctx = {}
--                     preview:restore(v.linkedTo.bundleID, hs.fnutils.copy(v.appCtx))
--                 end
--             end
--         end
--         self.__events:start()
--         self.__dump_timer = hs.timer.doEvery(2, function()
--             local locked = hs.fnutils.filter(self.__registered, function(p)
--                 return p.lockpad.locked
--             end)
--             local view = {}
--             for i, p in ipairs(locked) do
--                 view[i] = p:dump()
--             end
--             hs.json.write(view, hs.configdir .. '/preview.json', true, true)
--         end)
--         return self
--     end

--     function self:register(preview)
--         if self.hidden then
--             preview:hide()
--         else
--             preview:show()
--         end
--         table.insert(self.__registered, preview)
--         if self.__recoverState[preview.id] then
--             self.__recoverState[preview.id](preview)
--             self.__recoverState[preview.id] = nil
--         end
--         return preview
--     end

--     function self:show()
--         self.bg:show()
--         for _, p in ipairs(self.__registered) do
--             p:show()
--         end
--         self.hidden = false
--         return self
--     end

--     function self:hide()
--         self.bg:hide()
--         for _, p in ipairs(self.__registered) do
--             p:hide()
--         end
--         self.hidden = true
--         return self
--     end

--     function self:zen()
--         hs.spaces.toggleMissionControl()
--         return self
--     end

--     function self:onFocus(preview)
--         if self.__current_focus and self.__current_focus ~= preview then
--             table.insert(self.__history, 1, self.__current_focus)
--         end
--         self.__current_focus = preview
--         if #self.__history > 20 then
--             table.remove(self.__history, #self.__history)
--         end

--         hs.timer.doAfter(0.2, function()
--             self:compact()
--         end)

--         return self
--     end

--     function self:onClear(preview)
--         self:compact()
--         return self
--     end

--     function self:onLink(preview)
--         self:compact()
--         return self
--     end

--     function self:back(offset)
--         if offset == nil then
--             offset = 1
--         end
--         if #self.__history < offset then
--             return false
--         end
--         if self.__history[offset] == self.__current_focus then
--             return false
--         end

--         self.__history[offset]:activate()
--         return true
--     end

--     function self:dump()
--         self.__dump_timer:start()
--     end

--     ---@param targetState hs.window[]
--     function self:redistribute(targetState)
--         -- removed outdated
--         for _, p in ipairs(self.__registered) do
--             if p and p:linkedTo() and not p.lockpad.locked then
--                 if not hs.fnutils.contains(targetState, p:linkedTo()) then
--                     p:clear()
--                 end
--             end
--         end
--         local slotInfo = hs.fnutils.map(self.__registered, function(v)
--             if not v.lockpad.locked then
--                 if v:linkedTo() then return {
--                     provides = {v:linkedTo()},
--                     accepts = function (w) return false end,
--                 }
--                 else return {
--                     -- provides = funtion() 
--                     accepts = function(w) return true end}
--                 end
--             else
--                 if v:linkedTo() then return {
--                     provides = {v:linkedTo()}, accepts = {}}
--                 else
--                     if v.bundleID then return {
--                         provides = {},
--                         accepts = {
--                             hs.fnutils.filter(self.__registered, function(w) return w:application():bundleID() == v.bundleID end),
--                         }
--                     }
--                 end
--             end

--             return {}
--         end)
--         for idx, w in ipairs(self.__registered) do
--             local found = false
--             for _, p in ipairs(self.__registered) do
--                 if p and p:linkedTo() and not p.lockpad.locked then
--                     if p:linkedTo() == w then
--                         found = true
--                         break
--                     end
--                 end
--             end
--             if not found then
--                 local preview = Preview:new(w)
--                 self:register(preview)
--             end
--         end
--     end

--     function self:compact()
--         -- ---@type preview[]
--         -- local nonLocked = hs.fnutils.filter(self.__registered, function(p)
--         --     return not p.lockpad.locked
--         -- end) or {}
--         -- for i = #self.__registered, 1, -1 do
--         --     local p = self.__registered[i]
--         --     local relocatable = p.lockpad.locked
--         --     local applicable = #nonLocked > 0 and nonLocked[1].id < i
--         --     if relocatable and applicable then
--         --         local nextToJoin = table.remove(nonLocked, 1)
--         --         self.__registered[i] = nextToJoin
--         --         self.__registered[nextToJoin.id] = p
--         --         p:swap(nextToJoin)
--         --     end
--         -- end

--         -- ---@type preview[]
--         -- local emptyList = hs.fnutils.filter(self.__registered, function(p)
--         --     return p:linkedTo() == nil and not p.lockpad.locked
--         -- end) or {}
--         -- for i = #self.__registered,1,-1 do
--         --     local p = self.__registered[i]
--         --     local relocatable = p:linkedTo() ~= nil and not p.lockpad.locked
--         --     local applicable = #emptyList > 0 and emptyList[1].id < i
--         --     if relocatable and applicable then
--         --         local nextToJoin = table.remove(emptyList, 1)
--         --         nextToJoin:join(p:linkedTo())
--         --         p:clear()
--         --     end
--         -- end
--     end

--     return self
-- end



-- function renderer()
--     local frame = hs.screen.mainScreen():fullFrame()
--     local log = hs.logger.new('alttaber.renderer', 'info')

--     local capacity = { 1, 2, 3, 4, 5, 6, 7, 8}
--     local height = 0.95 / #capacity
--     local dockSize = 0
--     local previewRect = hs.fnutils.map(capacity, function(i)
--         return hs.geometry.new({
--             x = dockSize,
--             y = (0.05 + height * (i - 1)) * frame.h,
--             h = height * frame.h,
--             w = 0.15 * frame.w-dockSize,
--         }):floor()
--     end)
--     local systemRect = hs.geometry.new({
--         x = dockSize,
--         y = 0,
--         h = 1 * frame.h,
--         w = 0.15 * frame.w - dockSize,
--     }):floor()

--     local filter = hs.window.filter.new(
--         hs.window.filter.default, 'alttaber.renderer', 'info'
--     ):setDefaultFilter({
--         hasTitlebar = true,
--         -- rejectRegions = systemRect,
--     }):rejectApp("Alfred 4"):rejectApp("Hammerspoon"):rejectApp("Alfred")

--     local gridFilter = hs.window.filter.copy(filter, 'alttaber.renderer', 'info')


--     local fgrid = {
--         { gridFilter, 'mov all foc [15,0,100,100] 0,0' },

--     }
--     local layout = hs.window.layout.new(fgrid, 'alttaber.renderer', 'info')


--     local bg = previewGroup():init(frame)
--     local previews = hs.fnutils.map(previewRect, function(r) return preview(bg):init(r) end)

--     local getWindows = function()
--         local focused = filter:getWindows(hs.window.filter.sortByFocusedLast)
--         local created = filter:getWindows(hs.window.filter.sortByCreatedLast)
--         local sorted = {}
--         local skipList = {}
--         for i = 1, math.min(4, #focused) do
--             table.insert(sorted, focused[i])
--             skipList[focused[i]:id()] = true
--         end
--         for i = 1, #created do
--             if not skipList[created[i]:id()] then
--                 table.insert(sorted, created[i])
--                 skipList[created[i]:id()] = true
--             end
--             if #sorted >= #capacity then
--                 break
--             end
--         end
--         return sorted
--     end


--     return {
--         previewGroup = bg,

--         start = function()
--             log:d('starting')
--             layout:start()

--             bg:show()

--             hs.timer.doEvery(1, function()
--                 bg:redistribute(getWindows())
--             end)

--             filter:subscribe({ hs.window.filter.windowsChanged }, function(_w, appName, event)
--                 bg:redistribute(getWindows())
--             end, true)
--         end,

--         stop = function()
--             log:d('stopping')
--             layout:stop()

--             bg:hide()
--         end,
--     }
-- end

-- hs.menuIcon(true)
-- hs.hotkey.bind({ 'cmd', 'alt' }, 'r', function()
--     hs.reload()
-- end, nil, nil)

-- local ctrl = renderer()
-- ctrl.start()

-- hs.hotkey.bind({ 'cmd', 'alt' }, 'h', function()
--     if ctrl.previewGroup.hidden then
--         ctrl.previewGroup:show()
--     else
--         ctrl.previewGroup:hide()
--     end
-- end, nil, nil)
