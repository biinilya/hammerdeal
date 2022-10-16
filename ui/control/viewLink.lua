---@class ui.control.viewLink
---@field private __view ui.preview.window
---@field private __window hs.window
---@field private __appName string
---@field private __id number
---@field private __oldBackground hs.image
---@field private __snapshotTimer hs.timer
local viewLink = {}
viewLink.__index = viewLink
viewLink.__name = 'viewLink'
viewLink.__lastId = 0

---@param view ui.preview.window
---@param onDetach fun(ui.control.viewLink)
---@return ui.control.viewLink
function viewLink:new(view, onDetach)
    self.__lastId = self.__lastId + 1
    local o = {}
    setmetatable(o, self)
    o.__id = self.__lastId
    o.log = hs.logger.new('ui.control.viewLink['..o.__id..']', 'debug')
    o.__view = view
    o.__onDetach = onDetach
    return o
end

---@param window hs.window
---@param appName string
---@return ui.control.viewLink
function viewLink:attachToWindow(window, appName)
    self.log.df('attachToWindow(%s, %s)', window:title(), appName)
    self.__window = window
    self.__appName = appName or window:application():name()
    self.__oldBackground = self.__view:state():background()
    self.__view:updatePreview(self:snapshotStub())
    self.__view:onClickedHook(function()
        window:focus()
    end)
    self.__wf = hs.window.filter.new({
        [self.__appName] = true,
        default = false,
    }):subscribe({hs.window.filter.windowFocused}, function(window, appName, event)
        if window:id() == self.__window:id() then
            self.__view:state():focused(true):apply()
        end
    end):subscribe({hs.window.filter.windowUnfocused}, function(window, appName, event)
        if window:id() == self.__window:id() then
            self.__view:state():focused(false):apply()
        end
    end):subscribe({hs.window.filter.windowDestroyed}, function(window, appName, event)
        self.log.df('windowDestroyed: %s', self.__window:id())
        if window:id() == self.__window:id() then
            self:detach()
        end
    end)
    self.__snapshotTimer = hs.timer.doEvery(1, function()
        if self.__window ~= nil then
            self.__view:updatePreview(self:snapshot(false))
            collectgarbage('step')
        end
    end)
    return self
end

---@param window hs.window
---@param appName string
---@return boolean
function viewLink:attachedTo(window, appName)
    return self.__window:id() == window:id() and self.__appName == appName
end

---@param appName string
---@return ui.control.viewLink
function viewLink:attachToApplication(appName)
    self.log.df('attachToApplication(%s)', appName)
    self.__appName = appName
    return self
end

---@param withStab boolean
---@return hs.image
function viewLink:snapshot(withStab)
    ---@type hs.image
    local r = self.__window:snapshot(true)
    if r ~= nil then
        return r:setSize({w = r:size().w, h = r:size().h})
    end
    if r == nil and withStab then
        return self:snapshotStub()
    end
end

---@return ui.control.viewLink
function viewLink:detach()
    if self.__window ~= nil then
        self.log.df('detach(%s, %s)', self.__window:title(), self.__appName)
    else
        self.log.df('duplicate detach')
    end
    if self.__wf ~= nil then
        self.__wf:unsubscribeAll()
        self.__wf:pause()
        self.__wf = nil
    end
    self.__window = nil
    self.__appName = nil
    if self.__snapshotTimer ~= nil then
        self.__snapshotTimer:stop()
        self.__snapshotTimer = nil
    end
    self.__view:state():reset():apply()
    self.__onDetach(self)
    return self
end

---@return ui.control.viewLink
function viewLink:snapshotStub()
    hs.fs.mkdir(hs.configdir .. '/cache')
    local snapshotFile = hs.configdir .. '/cache/' .. self.__appName .. '.png'
    local oldSnapshot = hs.image.imageFromPath(snapshotFile)
    if oldSnapshot then return oldSnapshot end

    local frame = hs.screen.mainScreen():frame()
    local app = hs.application.get(self.__appName)
    if app ~= nil then
        local tmpImg = hs.canvas.new({x = 0, y = 0, h = frame.h/10, w = frame.w/10 })
            :appendElements({
                type = 'image',
                image = hs.image.imageFromAppBundle(app:bundleID()),
                imageAlignment = 'right',
                imageAlpha = 1,
                imageScaling = 'scaleProportionally',
            }, {
                type = "rectangle",
                action = "fill",
                fillGradientColors = {
                    { hex = "#37474F", alpha = 0.7 },
                    { hex = "#263238", alpha = 0.6 },
                },
                fillGradient = "radial"
            }):imageFromCanvas()
        if tmpImg ~= nil then
            tmpImg:saveToFile(snapshotFile)
            return tmpImg
        end
    end
end

-----@param other ui.control.viewLink
--function viewLink:swap(other)
--    local otherWindow = other.__window
--    local otherAppName = other.__appName
--    local selfWindow = self.__window
--    local selfAppName = self.__appName
--    self:detach()
--    other:detach()
--    self:attachToWindow(otherWindow, otherAppName)
--    other:attachToWindow(selfWindow, selfAppName)
--end

return viewLink
