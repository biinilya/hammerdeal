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
function viewLink:new(view, wf, onAttach, onDetach, onAttachToApplication, onDetachFromApplication)
    self.__lastId = self.__lastId + 1
    local o = {}
    setmetatable(o, self)
    o.__id = self.__lastId
    o.__defaultLayout = hs.keycodes.layouts()[1]
    o.log = hs.logger.new('ui.control.viewLink['..o.__id..']', 'warning')
    o.__wf = wf
    o.__view = view
    o.__onAttach = onAttach
    o.__onDetach = onDetach
    o.__onAttachToApplication = onAttachToApplication
    o.__onDetachFromApplication = onDetachFromApplication
    o.__view:onClickedHook(function()
        if o.__window ~= nil  then
            o.__window:focus()
        else
            hs.eventtap.keyStroke({'cmd'}, 'space')
        end
    end)
    return o
end

---@param window hs.window
---@param appName string
---@return ui.control.viewLink
function viewLink:attachToWindow(_window, appName)
    self.log.df('attachToWindow(%s, %s)', _window:title(), appName)
    self.__window = _window
    self.__appName = appName or self.__window:application():name()
    self.__oldBackground = self.__view:state():background()
    self.__view:updatePreview(self:snapshotStub())
    self.__view:onLockedHook(function(isLocked)
        if isLocked then
            self:attachToApplication(self.__appName)
        else
            self:detachFromApplication(self.__appName)
        end
    end)
    self.__wf = hs.window.filter.new(function(w)
        if self.__window == nil then
            return false
        end
        if w:id() == 0 then
            return nil
        end
        return w:id() == self.__window:id()
    end):subscribe({hs.window.filter.hasWindow}, function(window, appName, event)
        self.__view:state():focused(true):apply()
    end, true):subscribe({hs.window.filter.windowFocused}, function(window, appName, event)
        self.__view:state():focused(true):apply()
        hs.keycodes.setMethod(self.__defaultLayout)
    end, true):subscribe({hs.window.filter.windowUnfocused}, function(window, appName, event)
        self.__view:state():focused(false):apply()
    end, true):subscribe({hs.window.filter.windowDestroyed}, function(window, appName, event)
        self.log.df('windowDestroyed: %s', hs.inspect.inspect(self.__window))
        self:detach()
    end, true)
    self.__snapshotTimer = hs.timer.doEvery(1, function()
        if self.__window ~= nil and self.__window ~= nil then
            self.__view:updatePreview(self:snapshot(false))
            collectgarbage('step')
        end
    end)
    self.__onAttach(self)
    return self
end

---@param window hs.window
---@return boolean
function viewLink:attachedToWindow(window)
    if window == nil then
        return self.__window ~= nil and self.__window:id()
    end
    return self.__window == window
end

---@param appName string
---@return boolean
function viewLink:attachedToApplication(appName)
    if appName == nil then
        return self.__app ~= nil and self.__app:name()
    end
    return self.__app:name() == appName
end

---@param appName string
---@return ui.control.viewLink
function viewLink:attachToApplication(appName)
    self.log.df('attachToApplication(%s)', appName)
    self.__app = hs.application.get(appName)
    self.__onAttachToApplication(self)
    return self
end

---@param appName string
---@return ui.control.viewLink
function viewLink:detachFromApplication(appName)
    self.log.df('detachFromApplication(%s)', appName)
    self.__app = nil
    self.__onDetachFromApplication(self)
    return self
end

function viewLink:attachmentInfo()
    return {
        idx = self.__id,
        toApp = self:attachedToApplication(),
        toWindow = self:attachedToWindow(),
        window = self.__window and {
            id = self.__window:id(),
            title = self.__window:title(),
        },
        app = self.__app and {
            id = self.__app:bundleID(),
            name = self.__app:name(),
        },
        appName = self.__appName,
        defaultLayout = self.__defaultLayout
    }
end


function viewLink:attachTo(attachmentInfo)
    print(hs.inspect.inspect(attachmentInfo))
    if attachmentInfo.toWindow then
        self:attachToWindow(hs.window(attachmentInfo.window.id), attachmentInfo.appName)
    end
    if attachmentInfo.toApp then
        self:attachToApplication(attachmentInfo.app.id)
        self.__onAttachToApplication(self)
    end
end


---@param withStab boolean
---@return hs.image
function viewLink:snapshot(withStab)
    ---@type hs.image
    local r = self.__window:snapshot(true)
    if r ~= nil then
        self.__lastSnapshot = r:setSize({w = r:size().w, h = r:size().h})
        return self.__lastSnapshot
    end
    if r == nil and withStab then
        return self:snapshotStub()
    end
end

---@return ui.control.viewLink
function viewLink:detach()
    self.log.df('detach(%s, %s)', hs.inspect.inspect(self.__window), self.__appName)
    self.__window = nil
    self.__appName = self.__app ~= nil and self.__app:name() or nil
    self.__lastSnapshot = nil
    if self.__wf ~= nil then
        self.__wf:unsubscribeAll()
        self.__wf:pause()
        self.__wf = nil
    end
    if self.__snapshotTimer ~= nil then
        self.__snapshotTimer:stop()
        self.__snapshotTimer = nil
    end
    self.__lastSnapshot = nil
    if self.__view ~= nil then
        self.__view:reset()
    end
    if self.__app == nil then
        return self.__onDetach(self)
    else
        hs.application.launchOrFocusByBundleID(self.__app:bundleID())
    end
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

---@param other ui.control.viewLink
function viewLink:swap(other)
    local localFrame =  self.__view:canvas():frame()
    local otherFrame = other.__view:canvas():frame()
    local localIdx = self.__id
    local otherIdx = other.__id
    self.__view:canvas():frame(otherFrame)
    other.__view:canvas():frame(localFrame)
    self.__id = otherIdx
    other.__id = localIdx
end

function viewLink:activate()
    if self.__window ~= nil then
        self.__window:focus()
    end
end

function viewLink:setLayoutMethod(layoutMethod)
    self.__defaultLayout = layoutMethod
end

function viewLink:getLayoutMethod()
    return self.__defaultLayout
end


return viewLink
