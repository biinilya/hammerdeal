---@class ui.frame
local frame = {}
frame.__index = frame
frame.__name = 'frame'

---@param x number
---@param y number
---@param w number
---@param h number
---@return ui.frame
function frame:pixels(x, y, w, h)
    local o = {}
    local f = hs.screen.mainScreen():fullFrame()
    o.x = 100 * x // f.w
    o.y = 100 * y // f.h
    o.w = 100 * w // f.w
    o.h = 100 * h // f.h

    setmetatable(o, self)
    return o
end

---@return ui.frame
function frame:fractions(x, y, w, h)
    local o = {}
    o.x = 100 * x // 1
    o.y = 100 * y // 1
    o.w = 100 * w // 1
    o.h = 100 * h // 1

    setmetatable(o, self)
    return o
end

--function frame:toCanvas()
--    return {
--        x = string.format('%d%%', self.x),
--        y = string.format('%d%%', self.y),
--        w = string.format('%d%%', self.w),
--        h = string.format('%d%%', self.h),
--    }
--end

---@param f ui.frame
function frame:rect(f)
    if f == nil then f = hs.screen.mainScreen():fullFrame() end
    if f.__name == 'frame' then
        f = f:rect()
    end
    local frame = hs.screen.mainScreen():fullFrame()
    return {
        x = tonumber(string.format("%d", (self.x * f.w + f.x) // 100)),
        y = tonumber(string.format("%d", (self.y * f.h + f.y) // 100)),
        w = tonumber(string.format("%d", self.w * f.w // 100)),
        h = tonumber(string.format("%d", self.h * f.h // 100)),
    }
end

return frame
