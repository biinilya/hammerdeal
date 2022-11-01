---@type hs.image
local _openImg = hs.image.imageFromPath(hs.configdir .. "/unlock.png")
---@type hs.image
local _closeImg = hs.image.imageFromPath(hs.configdir .. "/lock.png")
---@type hs.image

---@class ui.preview.state
---@field id string
local state = {}
state.__index = state
state.__name = 'state'

---@type hs.geometry
local workspace = hs.geometry { 0.15, 0.05, 0.80, 0.90 }
local filler = hs.canvas.new({ w = 276, h = 200 }):appendElements({
    type = "rectangle",
    action = "fill",
    fillColor = { white = 0.1, alpha = 0.0 },
    frame = { x = "0%", y = "0%", h = "100%", w = "100%" },
    padding = 0,
}):imageFromCanvas()


---@return ui.preview.state
function state:new()
    local o = {}
    setmetatable(o, self)
    o.id = hs.host.uuid()

    return o
        :locked(false)
        :highlighted(false)
        :background(filler)
        :lockerHighlighted(false)
        :lockerVisible(false)
        :visible(false)
end

function state:onAttach(cb)
    self.__notifyCb = cb
    return self
end

function state:onDetach()
    self.__notifyCb = nil
    return self
end

function state:apply()
    if self.__notifyCb ~= nil then
        self.__notifyCb()
    end
    return self
end

---@param f boolean | nil
---@return boolean | ui.preview.state
function state:locked(f)
    if f ~= nil then
        self._locked = f
        self._lockerImg = f and _closeImg or _openImg
        return self
    end
    return self._locked
end

---@return boolean | ui.preview.state
function state:shifted()
    return self:locked() or self:focused()
end

---@return hs.image | ui.preview.state
function state:lockerImg()
    return self._lockerImg
end

---@param f boolean | nil
---@return boolean | ui.preview.state
function state:highlighted(f)
    if f ~= nil then
        self._highlighted = f
        return self
    end
    return self._highlighted
end

---@param f boolean | nil
---@return boolean | ui.preview.state
function state:lockerHighlighted(f)
    if f ~= nil then
        self._lockerHighlighted = f
        return self
    end
    return self._lockerHighlighted
end

---@param f boolean | nil
---@return boolean | ui.preview.state
function state:visible(f)
    if f ~= nil then
        self._visible = f
        return self
    end
    return self._visible
end

---@param f boolean | nil
---@return boolean | ui.preview.state
function state:focused(f)
    if f ~= nil then
        self._focused = f
        return self
    end
    return self._focused
end

---@param f boolean | nil
---@return boolean | ui.preview.state
function state:lockerVisible(f)
    if f ~= nil then
        self._lockerVisible = f
        return self
    end
    return self._lockerVisible
end

---@param f hs.image | nil
---@return hs.image | ui.preview.state
function state:background(f)
    if f ~= nil then
        self._background = f
        return self
    end
    return self._background
end

---@param f hs.image | nil
---@return hs.image | ui.preview.state
function state:logo(f)
    if f ~= nil then
        self._logo = f
        return self
    end
    return self._logo
end

---@return table<string, fun()>
function state:hooks()
    if self._hooks == nil then
        self._hooks = {}
    end
    return self._hooks
end

---@return ui.preview.state
function state:reset()
    self
        :locked(false)
        :highlighted(false)
        :background(filler)
        :lockerHighlighted(false)
        :lockerVisible(false)
        :focused(false)
    return self
end

return state
