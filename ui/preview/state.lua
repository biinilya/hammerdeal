---@type hs.image
local _openImg = hs.image.imageFromPath(hs.configdir .. "/unlock.png")
---@type hs.image
local _closeImg = hs.image.imageFromPath(hs.configdir .. "/lock.png")
---@type hs.image

---@class ui.preview.state
local state = {}
state.__index = state
state.__name = 'state'
---@type ui.preview.window
state.super = nil

---@type ui.frame
local workspaceArea = require 'ui.frame':fractions(0.15, 0,0.85, 1.0)
local filler = hs.canvas.new(workspaceArea:rect()):appendElements({
    type = "rectangle",
    action = "fill",
    fillColor = { white = 0.1, alpha = 0.5 },
    frame = { x = "0%", y = "0%", h = "100%", w = "100%" },
    padding = 0,
}):imageFromCanvas()

---@param super ui.preview.window
---@return ui.preview.state
function state:new(super)
    local o = {}
    setmetatable(o, self)

    return o
        :super(super)
        :locked(false)
        :highlighted(false)
        :background(filler)
        :lockerHighlighted(false)
        :lockerVisible(false)
        :visible(false)
end

---@param f boolean
---@return boolean | ui.preview.state
function state:locked(f)
    if f ~= nil then
        self._locked = f
        self._lockerImg = f and _closeImg or _openImg
        return self
    end
    return self._locked
end

---@return boolean
function state:shifted()
    return self:locked() or self:focused()
end

---@return hs.image | ui.preview.state
function state:lockerImg()
    return self._lockerImg
end

---@param f boolean
---@return boolean | ui.preview.state
function state:highlighted(f)
    if f ~= nil then
        self._highlighted = f
        return self
    end
    return self._highlighted
end

---@param f boolean
---@return boolean | ui.preview.state
function state:lockerHighlighted(f)
    if f ~= nil then
        self._lockerHighlighted = f
        return self
    end
    return self._lockerHighlighted
end

---@param f boolean
---@return boolean | ui.preview.state
function state:visible(f)
    if f ~= nil then
        self._visible = f
        return self
    end
    return self._visible
end

---@param f boolean
---@return boolean | ui.preview.state
function state:focused(f)
    if f ~= nil then
        self._focused = f
        return self
    end
    return self._focused
end

---@param f boolean
---@return boolean | ui.preview.state
function state:lockerVisible(f)
    if f ~= nil then
        self._lockerVisible = f
        return self
    end
    return self._lockerVisible
end

---@param f hs.image
---@return hs.image | ui.preview.state
function state:background(f)
    if f ~= nil then
        self._background = f
        return self
    end
    return self._background
end

---@return ui.preview.state
function state:reset()
    return self
        :locked(false)
        :highlighted(false)
        :background(filler)
        :lockerHighlighted(false)
        :lockerVisible(false)
        :focused(false)
end

---@param f ui.preview.window
---@return ui.preview.window | ui.preview.state
function state:super(f)
    if f ~= nil then
        self._super = f
        return self
    end
    return self._super
end

---@return ui.preview.window
function state:apply()
    return self:super():apply()
end

return state
