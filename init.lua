---@diagnostic disable: need-check-nil
local window = require "hs.window"
local eventtap = require "hs.eventtap"
local canvas   = require "hs.canvas"
local touchdevice = require "hs._asm.undocumented.touchdevice"
local touchdevices = require "hs._asm.undocumented.touchdevice.watcher"


hs.window.animationDuration = 0.0
hs.application.enableSpotlightForNameSearches(true)

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

local function lockpad()
    local self = {}
    self.__index = self
    self.locked = false
    self.parent = nil

    function self:init(preview)
        self.frame = preview.frame
        self.parent = preview
        self.canvas = hs.canvas.new(self.frame):appendElements({
            type = 'image',
            action = 'strokeAndFill',
            image = hs.image.imageFromPath(hs.configdir .. "/unlock.png"),
            imageAlignment = 'left',
            imageAlpha = 0.7,
            padding = self.frame.h * 0.05,
            frame = { x = "20%", y = "30%", h = "40%", w = "40%" },
        }):canvasMouseEvents(
            true, true, true, true
        ):draggingCallback(function(canvas, event, obj)
            self:ondnd(canvas, event, obj)
        end):level(
            hs.canvas.windowLevels.dragging
        ):mouseCallback(function(canvas, eventType, elementId, x, y)
            self:onMouse(canvas, eventType, elementId, x, y)
        end):wantsLayer(
            true
        ):behaviorAsLabels({
            "canJoinAllSpaces", 'stationary',
        })
        return self
    end

    function self:lock()
        self.locked = true
        self.canvas:elementAttribute(1, 'image', hs.image.imageFromPath(hs.configdir .. "/lock.png"))
        self.parent:lock()
    end

    function self:unlock()
        self.locked = false
        self.canvas:elementAttribute(1, 'image', hs.image.imageFromPath(hs.configdir .. "/unlock.png"))
        self.parent:unlock()
    end

    function self:switch()
        if self.locked then
            self:unlock()
        else
            self:lock()
        end
    end

    function self:ondnd(canvas, event, obj)
        if event == 'enter' then
            local ctx = {}
            self.dNdContext[obj.sequence] = ctx
        elseif event == 'exit' then
            local ctx = self.dNdContext[obj.sequence]
            self.dNdContext[obj.sequence] = nil
        else
        end
    end

    function self:onMouse(canvas, eventType, elementId, x, y)
        if eventType == 'mouseDown' then
            self:switch()
            return
        end
        if eventType == 'mouseEnter' then
            self.canvas:elementAttribute(1, 'imageAlpha', 1)
            self.parent:onLockAreaMouseEnter()
            return
        end
        if eventType == 'mouseExit' then
            self.canvas:elementAttribute(1, 'imageAlpha', 0.7)
            self.parent:onLockAreaMouseExit()
            return
        end
    end

    return self
end

local function preview(grp)
    local self = {}
    self.__index = self
    self.dNdContext = {}
    self.id = grp:next()

    self.lockpad = lockpad()
    self.appCtx = {
        preferredLayout = nil
    }


    function self:init(frame)
        self.frame = frame
        self.canvas = hs.canvas.new(self.frame):appendElements({
            type = 'image',
            action = 'strokeAndFill',
            image = filler,
            imageAlignment = 'left',
            imageAlpha = 1.0,
            padding = self.frame.h * 0.05,
        }, {
            type = 'canvas',
            canvas = self.lockpad.canvas,
        }):canvasMouseEvents(
            true, true, true, true
        ):draggingCallback(function(canvas, event, obj)
            return self:ondnd(canvas, event, obj)
        end):level(
            hs.canvas.windowLevels.floating
        ):mouseCallback(function(canvas, eventType, elementId, x, y)
            return self:onMouse(canvas, eventType, elementId, x, y)
        end):wantsLayer(
            true
        ):behaviorAsLabels({ 
            "canJoinAllSpaces", 'stationary',
        }):show()

        self.lockpad:init(self)

        self.window = nil
        self.filter = nil

        return grp:register(self)
    end

    function self:ondnd(canvas, event, obj)
        if event == 'enter' then
            local content = hs.pasteboard.readURL(obj.pasteboard)
            dump(content)
            if not content.filePath then return false end
            local appInfo = hs.application.infoForBundlePath(content.filePath)
            if not appInfo then return false end
            local ctx = {
                app = appInfo
            }
            self.dNdContext[obj.sequence] = ctx
            return true
        elseif event == 'exit' then
            self.dNdContext[obj.sequence] = nil
        else
            local ctx = self.dNdContext[obj.sequence]
            dump(ctx)
            local bundleID = ctx.app.CFBundleIdentifier
            self:clear()
            self:restore(bundleID, {})
        end
    end

    function self:onMouse(canvas, eventType, elementId, x, y)
        if eventType == 'mouseDown' then
            -- if self.focused then
            --     grp:zen()
            --     return
            -- end
            if self.window == nil then
                hs.application.open("Alfred 4")
                return
            end
            self:activate()
            return
        end
        if eventType == 'mouseEnter' then
            if self.bundleID == nil then
                return
            end
            self.mouseEnterTracker = hs.timer.doEvery(0.05, function()
                if hs.eventtap.checkKeyboardModifiers().alt then
                    self:onLockAreaActivated()
                end
            end):start()
            return
        end
        if eventType == 'mouseExit' then
            if self.mouseEnterTracker then
                self.mouseEnterTracker:stop()
            end
            return
        end
    end

    function self:onLockAreaActivated()
        self.mouseEnterTracker:stop()
        self.lockpad.canvas:show()
        self.mouseExitTracker = hs.timer.doEvery(0.05, function()
            if not hs.eventtap.checkKeyboardModifiers().alt then
                self:onLockAreaDeactivated()
            end
        end):start()

    end

    function self:onLockAreaDeactivated()
        self.mouseExitTracker:stop()
        self.lockpad.canvas:hide()
        if self.mouseEnterTracker then
            self.mouseEnterTracker:stop()
        end
    end

    function self:onLockAreaMouseEnter()
        self.canvas:elementAttribute(1, 'imageAlpha', 0.7)
        if self.onLockAreaCountdown ~= nil then
            self.onLockAreaCountdown:stop()
        end
    end

    function self:onLockAreaMouseExit()
        self.canvas:elementAttribute(1, 'imageAlpha', 1)
        self:onLockAreaDeactivated()
    end

    function self:join(w)
        if self.lockpad.locked and not w:application():bundleID() == self.bundleID then
            return nil, 'locked'
        end

        if w and self.window and self.window:id() == w:id() then
            return nil, 'same'
        end

        if self.window ~= nil then
            self:clear()
        end
        self.window = w
        self.bundleID = w:application():bundleID()
        self.filter = hs.window.filter.new(
            function(_w)
                return self.window ~= nil and _w ~= nil and _w:id() == self.window:id()
            end,
            'preview:' .. self.id
        ):subscribe(
            { hs.window.filter.windowFocused },
            function(_w, appName, event)
                self.window = _w
                self:focus(true)
            end,
            true
        ):subscribe(
            { hs.window.filter.windowUnfocused },
            function(_w, appName, event)
                self:focus(false)
            end,
            true
        ):subscribe(
            { hs.window.filter.windowRejected },
            function(_w, appName, event)
                self:clear()
            end,
            true
        )

        self.appCtx.preferredLayout = self.appCtx.preferredLayout or hs.keycodes.layouts()[1]

        self.snapshotter = hs.timer.delayed.new(hs.math.randomFloat()*0.2 + 1.0, function()
            self.snapshotter:start()
            self:snapshot()
        end):start()

        grp:onLink(self)
        self.canvas:show(1)
        return self
    end

    function self:dummySnapshot()
        hs.fs.mkdir(hs.configdir .. '/cache')
        self.snapshotFile = hs.configdir .. '/cache/' .. self.bundleID or self.window:application():bundleID() .. '.png'
        self.oldSnapshot = hs.image.imageFromPath(self.snapshotFile)
        if self.oldSnapshot then
            self.canvas:elementAttribute(1, 'image', self.oldSnapshot)
        else
            local tmpImg = hs.canvas.new(self.canvas:frame()):appendElements({
                type = 'image',
                image = hs.image.imageFromAppBundle(self.bundleID or self.window:application():bundleID()),
                imageAlignment = 'left',
                imageAlpha = 1,
                padding = self.frame.h * 0.05,
                imageScaling = 'scaleToFit',
            }, {
                type = "rectangle",
                action = "fill",
                fillGradientColors = {
                    { hex = "#37474F", alpha = 0.7 },
                    { hex = "#263238", alpha = 0.6 },

                }, fillGradient = "radial"
            }
            ):imageFromCanvas()
            self.canvas:elementAttribute(1, 'image', tmpImg)
        end

    end

    function self:clear()
        if self.lockpad.locked then
            return nil, 'locked'
        end

        if self.filter then
            self.filter:unsubscribeAll()
            self.filter = nil
        end
        self.window = nil
        self.bundleID = nil
        self.focused = false
        if self.snapshotter then
            self.snapshotter:stop()
        end
        self.canvas:elementAttribute(1, 'image', filler)
        self.canvas:elementAttribute(1, 'imageAlignment', 'left')
        self.appCtx = {
            preferredLayout = nil
        }

        grp:onClear(self)
        return self
    end

    function self:snapshot()
        if self.window == nil then
            return
        end
        local snapshot = self.window:snapshot()
        if snapshot == nil then return end
        if hs.window.focusedWindow() and hs.window.focusedWindow():id() == self.window:id() then
            self.appCtx.preferredLayout = hs.keycodes.currentLayout()
        end
        self.canvas:elementAttribute(1, 'image', snapshot)
        if not self.oldSnapshot and self.snapshotFile then
            snapshot:setSize({ h = 768, w = 1024 }):saveToFile(self.snapshotFile)
            self.oldSnapshot = true
        end

        collectgarbage('step')
        return snapshot
    end


    function self:linkedTo()
        return self.window
    end

    function self:focus(status)
        self.focused = status
        if self.focused or self.lockpad.locked then
            self.canvas:elementAttribute(1, 'imageAlignment', 'right')
        end
        if not self.focused and not self.lockpad.locked then
            self.canvas:elementAttribute(1, 'imageAlignment', 'left')
        end
        if self.focused then
            hs.keycodes.setLayout(self.appCtx.preferredLayout or hs.keycodes.layouts()[1])
            grp:onFocus(self)
        end

        return self
    end

    function self:lock()
        self:focus(true)
    end

    function self:unlock()
        self:focus(false)
    end

    function self:show()
        self.canvas:show()
        return self
    end

    function self:hide()
        self.canvas:hide()
        return self
    end

    function self:activate()
        if self.bundleID == nil then
            return
        end
        if self.window and hs.window.find(self.window:id()) then
            self.window:focus()
        else
            hs.application.open(self.bundleID)
        end
        self:focus(true)
        return self
    end

    function self:dump()
        return {
            id = self.id,
            linkedTo = {
                id = self.window:id(),
                title = self.window:title(),
                bundleID = self.window:application():bundleID()
            },
            appCtx = self.appCtx,
            preferredLayout = self.appCtx.preferredLayout,
        }
    end

    function self:restore(bundleID, appCtx)
        self.lockpad:lock()
        self.bundleID = bundleID
        self:dummySnapshot()
        self:activate()
        if appCtx == nil then appCtx = self.appCtx end
        self.appCtx = appCtx
        self.appCtx.preferredLayout = self.appCtx.preferredLayout or hs.keycodes.layouts()[1]

    end


    return self
end

local function previewGroup()
    local self = {}

    self.__index = self
    self.__items = 0
    self.__registered = {}
    self.__history = {}
    self.__focus = {}
    self.__alttab = nil
    self.__recoverState = {}

    function self:next()
        self.__items = self.__items + 1
        return self.__items
    end

    function self:init(frame)
        local bgRect = hs.geometry.new({ x = 0, y = 0, h = frame.h, w = frame.w }):floor()
        self.bg = hs.canvas.new(bgRect):appendElements({
            type = "image",
            action = "fill",
            image = hs.image.imageFromURL("file:///Users/ibiin/.hammerspoon/bg.png"),
            imageScaling = "scaleToFit",
            imageAlpha = 0.7,
            compositeRule = 'plusDarker',
        }):level(hs.canvas.windowLevels.desktopIcon)
        self.hidden = true
        self.__events = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.flagsChanged }, function(e)
            if e:getKeyCode() == 12 and e:getFlags()['alt'] then
                self.__current_focus:linkedTo():application():hide()
                return true
            end
            if e:getKeyCode() == 13 and e:getFlags()['alt'] then
                local app = self.__current_focus:linkedTo():application()
                app:hide()
                return true
            end
            if e:getKeyCode() == 31 and e:getFlags()['alt'] then
                hs.application.open("Alfred 4")
                return true
            end
            if e:getKeyCode() == 48 and e:getFlags()['alt'] then
                if self.__alttab == nil then
                    self.__alttab = {
                        index = -2
                    }
                end
                for i=1,#self.__registered do
                    self.__alttab.index = self.__alttab.index + 1
                    if self.__alttab.index < 1 then
                        if self:back(self.__alttab.index + 2)then
                            return true
                        end
                    else
                        local activePreviews = hs.fnutils.filter(self.__registered, function(v)
                            return v:linkedTo() ~= nil
                        end)
                        activePreviews[self.__alttab.index % #activePreviews + 1]:activate()
                        return true
                    end
                end
                return true
            end
            self.__alttab = nil
        end)
        local state = hs.json.read(hs.configdir .. '/preview.json')
        if state then
            for _, v in ipairs(state) do
                self.__recoverState[v.id] = function(preview)
                    local ctx = {}
                    preview:restore(v.linkedTo.bundleID, hs.fnutils.copy(v.appCtx))
                end
            end
        end
        self.__events:start()
        self.__dump_timer = hs.timer.doEvery(30, function()
            local locked = hs.fnutils.filter(self.__registered, function(p)
                return p.lockpad.locked
            end)
            local view = {}
            for i, p in ipairs(locked) do
                view[i] = p:dump()
            end
            hs.json.write(view, hs.configdir .. '/preview.json', true, true)
        end)
        return self
    end

    function self:register(preview)
        if self.hidden then
            preview:hide()
        else
            preview:show()
        end
        table.insert(self.__registered, preview)
        if self.__recoverState[preview.id] then
            self.__recoverState[preview.id](preview)
            self.__recoverState[preview.id] = nil
        end
        return preview
    end

    function self:show()
        self.bg:show()
        for _, p in ipairs(self.__registered) do
            p:show()
        end
        self.hidden = false
        return self
    end

    function self:hide()
        self.bg:hide()
        for _, p in ipairs(self.__registered) do
            p:hide()
        end
        self.hidden = true
        return self
    end

    function self:zen()
        hs.spaces.toggleMissionControl()
        return self
    end

    function self:onFocus(preview)
        self:dump()
        if self.__current_focus and self.__current_focus ~= preview then
            table.insert(self.__history, 1, self.__current_focus)
        end
        self.__current_focus = preview
        if #self.__history > 20 then
            table.remove(self.__history, #self.__history)
        end

        return self
    end

    function self:onClear(preview)
        hs.timer.doAfter(0.2,  function ()
            self:compact()
        end)
        return self
    end

    function self:onLink(preview)
        return self
    end

    function self:back(offset)
        if offset == nil then
            offset = 1
        end
        if #self.__history < offset then
            return false
        end
        if self.__history[offset] == self.__current_focus then
            return false
        end

        self.__history[offset]:activate()
        return true
    end

    function self:dump()
        self.__dump_timer:start()
    end

    function self:redistribute(targetState)
        local lockList = hs.fnutils.filter(self.__registered, function(p)
            return p.lockpad.locked
        end)

        local toDistribute = hs.fnutils.filter(targetState, function(p)
            local recepient = hs.fnutils.find(self.__registered, function(r)
                return p and p:application() and r.bundleID == p:application():bundleID()
            end)
            if recepient then
                recepient:join(p)
                return false
            end
            return true
        end)

        local current = hs.fnutils.map(self.__registered, function(p) return p:linkedTo() end)
        local canBeRemoved = hs.fnutils.filter(current, function(w)
            return not hs.fnutils.contains(toDistribute, w)
        end)
        local toAdd = hs.fnutils.filter(toDistribute, function(w)
            return not hs.fnutils.contains(current, w)
        end)
        for _, v in ipairs(self.__registered) do
            if v.bundleID == nil and #toAdd > 0 then
                v:join(table.remove(toAdd, 1))
            end
        end
        for _, v in ipairs(toAdd) do
            local nextToRemove = table.remove(canBeRemoved, 1)
            local p = hs.fnutils.find(self.__registered, function(p) return p.bundleID == nextToRemove and not p.lockpad.locked end)
            if p then
                p:clear(v)
                p:join(v)
            end
        end
    end

    function self:compact()
        local emptyList = hs.fnutils.filter(self.__registered, function(p)
            return p:linkedTo() == nil and not p.lockpad.locked
        end)
        for i = #self.__registered,1,-1 do
            local p = self.__registered[i]
            local relocatable = p:linkedTo() ~= nil and not p.lockpad.locked
            local applicable = #emptyList > 0 and emptyList[1].id < i
            if relocatable and applicable then
                local nextToJoin = table.remove(emptyList, 1)
                nextToJoin:join(p:linkedTo())
                p:clear()
            end
        end
    end

    return self
end


function renderer()
    local frame = hs.screen.mainScreen():fullFrame()
    local log = hs.logger.new('alttaber.renderer', 'info')

    local capacity = { 1, 2, 3, 4, 5, 6, 7, 8}
    local height = 0.95 / #capacity
    local dockSize = 0
    local previewRect = hs.fnutils.map(capacity, function(i)
        return hs.geometry.new({
            x = dockSize,
            y = (0.05 + height * (i - 1)) * frame.h,
            h = height * frame.h,
            w = 0.15 * frame.w-dockSize,
        }):floor()
    end)
    local systemRect = hs.geometry.new({
        x = dockSize,
        y = 0,
        h = 1 * frame.h,
        w = 0.15 * frame.w - dockSize,
    }):floor()

    local filter = hs.window.filter.new(
        hs.window.filter.default, 'alttaber.renderer', 'info'
    ):setDefaultFilter({
        hasTitlebar = true,
        -- rejectRegions = systemRect,
    }):rejectApp("Alfred 4"):rejectApp("Hammerspoon"):rejectApp("Alfred")

    local gridFilter = hs.window.filter.copy(filter, 'alttaber.renderer', 'info')


    local fgrid = {
        { gridFilter, 'mov all foc [15,0,100,100] 0,0' },

    }
    local layout = hs.window.layout.new(fgrid, 'alttaber.renderer', 'info')


    local bg = previewGroup():init(frame)
    local previews = hs.fnutils.map(previewRect, function(r) return preview(bg):init(r) end)

    local getWindows = function()
        local focused = filter:getWindows(hs.window.filter.sortByFocusedLast)
        local created = filter:getWindows(hs.window.filter.sortByCreatedLast)
        local sorted = {}
        local skipList = {}
        for i = 1, math.min(4, #focused) do
            table.insert(sorted, focused[i])
            skipList[focused[i]:id()] = true
        end
        for i = 1, #created do
            if not skipList[created[i]:id()] then
                table.insert(sorted, created[i])
                skipList[created[i]:id()] = true
            end
            if #sorted >= #capacity then
                break
            end
        end
        return sorted
    end


    return {
        previewGroup = bg,

        start = function()
            log.d('starting')
            layout:start()

            bg:show()

            filter:subscribe({ hs.window.filter.windowsChanged }, function(_w, appName, event)
                bg:redistribute(getWindows())
            end, true)
        end,

        stop = function()
            log.d('stopping')
            layout:stop()

            bg:hide()
        end,
    }
end

hs.menuIcon(true)
hs.hotkey.bind({ 'cmd', 'alt' }, 'r', function()
    hs.reload()
end, nil, nil)

local ctrl = renderer()
ctrl.start()
