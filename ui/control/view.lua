---@class ui.control.view
---@field state ui.preview.state
---@field cfg ui.cfg
---@field id string
---@field layout ui.control.layout
local M = {}
M.__index = M

---@param appName string
---@param layout ui.control.layout
---@return ui.control.view
function M:new(appName, layout)
    local o = {}
    setmetatable(o, self)
    o.cfg = ui.config:new(appName)
    o.id = appName .. '/' .. hs.host.uuid()
    o.layout = layout
    o.state = ui.preview.state:new():background(ui.preview.thumbnail(appName)):visible(true):apply()
    return o
end

function M:attach()
    self.layout:attach(self.id, self.state, self.cfg)
    self.state:visible(true):apply()
    return self
end

function M:detach()
    self.state:visible(false):apply()
    self.layout:detach(self.id)
end

---@param img hs.image
function M:update(img)
    self.state:background(img):apply()
end

return M