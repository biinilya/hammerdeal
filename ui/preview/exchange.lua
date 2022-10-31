---@class ui.preview.exchange
---@field public channel ui.preview.channel
---@field public w hs.watchable
---@field public path string
---@field public key string
---@field private log hs.logger
local exchange = {}
exchange.__index = exchange
exchange.__name = 'exchange'


---@param id string
---@param tag string
---@param loglevel string
---@return ui.preview.exchange
function exchange.new(id , tag, loglevel)
    local o = {}
    o.bucket = {}
    o.path = 'X:['..id..']:>'
    o.state = hs.watchable.new(o.path, true)
    o.log = hs.logger.new('x['..tag..']', loglevel)
    setmetatable(o, exchange)
    return o
end

return exchange
