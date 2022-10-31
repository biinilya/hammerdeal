---@class ui.preview.channel
---@field private subscribers (fun(watcher:hs.watchable, path:string, key:string, old:any, new:any))[]
---@field public path string
---@field public key string
---@field private w hs.watchable
local channel = {}
channel.__index = channel
channel.__name = 'channel'

local function repr(...)
    return hs.inspect.inspect({ ... }, { newline = '', indent = '' })
end

function channel:emit(data)
    if self.key == '*' then
        self.w:change( self.key, data)
    else
        self.w:change( data)
    end
end

function channel:subscribe(callback)
    table.insert(self.subscribers, callback)
    return self
end

function channel:publish(watcher, path, key, old, new)
    hs.fnutils.each(self.subscribers, function(subscriber)
        subscriber(new)
    end)
end

---@param others ui.preview.channel[]
---@return ui.preview.channel
function channel:andEachOf(others)
    local egress = self:topic(hs.host.uuid())
    local activators = {}
    for idx, other in ipairs(others) do
        other:subscribe(function(v)
            activators[idx] = ui.bool(v)
            egress:emit(ui.fn.every(activators, ui.bool))
        end)
        activators[idx] = false
    end
    table.insert(activators, false)
    self:subscribe(function(v)
        activators[#activators] = ui.bool(v)
        egress:emit(ui.fn.some(activators, ui.bool))
    end)
    return egress

end

---@param others ui.preview.channel[]
---@return ui.preview.channel
function channel:also(others)
    return self:andEachOf(others)
end

---@param others ui.preview.channel[]
---@return ui.preview.channel
function channel:orOneOf(others)
    local egress = self:topic(hs.host.uuid())
    local activators = {}
    for idx, other in ipairs(others) do
        other:subscribe(function(v)
            activators[idx] = ui.bool(v)
            egress:emit(ui.fn.some(activators, ui.bool))
        end)
        activators[idx] = false
    end
    table.insert(activators, false)
    self:subscribe(function(v)
        activators[#activators] = ui.bool(v)
        egress:emit(ui.fn.some(activators, ui.bool))
    end)
    return egress
end

---@param others ui.preview.channel[]
---@return ui.preview.channel
function channel:andNoneOf(others)
    local egress = self:topic(hs.host.uuid())
    local activators = {}
    for idx, other in ipairs(others) do
        other:subscribe(function(v)
            activators[idx] = ui.bool(v)
            egress:emit(not ui.fn.every(activators, ui.bool))
        end)
        activators[idx] = false
    end
    table.insert(activators, false)
    self:subscribe(function(v)
        activators[#activators] = ui.bool(v)
        egress:emit(ui.fn.some(activators, ui.bool))
    end)
    return egress
end

---@return ui.preview.channel
function channel:invert()
    local egress = self:topic('invert')
    self:subscribe(function(v) egress:emit(not ui.bool(v)) end)
    return egress
end

---@param blockLane ui.preview.channel
---@return ui.preview.channel
function channel:gate(blockLane)
    local s1 = false
    local s2 = false
    local egress = self:topic('gate')
    self:subscribe(function(v)
        s1 = ui.bool(v)
        egress:emit(s1 and not s2)
    end)
    blockLane:subscribe(function(v)
        s2 = ui.bool(v)
        egress:emit(s1 and not s2)
    end)
    return egress
end

---@param duration number
---@return ui.preview.channel
function channel:within(duration)
    if duration == nil then duration = 0.005 end
    local egress = self:topic('trigger')

    local initial
    local front = hs.timer.delayed.new(duration, function()
        egress:emit(not ui.bool(initial))
    end)
    self:subscribe(function(v)
        initial = ui.bool(v)
        front:start()
        egress:emit(initial)
    end)
    return egress
end

---@return ui.preview.channel
function channel:asap()
    return self:within(0.05)
end

---@param reset ui.preview.channel
---@return ui.preview.channel
function channel:unless(reset)
    local egress = self:topic('keeper')
    local locked = false
    self:subscribe(function(v)
        locked = locked or ui.bool(v)
        egress:emit(locked)
    end)

    reset:subscribe(function(v)
        locked = locked and not ui.bool(v)
    end)

    return egress
end

function channel.new(path, key)
    local o = {
        path = path,
        key = key,
        subscribers = {},
        logs_prefix = string.format('ui://%s/%-18s', path, key),
        log = hs.logger.new('channel', 'debug'),
        w = hs.watchable.watch(path, key),
    }
    setmetatable(o, channel)
    o.w:callback(function(watcher, path, key, old, new) return
        o:publish(watcher, path, key, old, new)
    end)
    return o
end

function channel:topic(topic)
    local o = {
        path = self.path,
        key = self.key .. '#' .. topic,
        subscribers = {},
        logs_prefix = string.format('ui://%s/%-18s', self.path, self.key .. '#' .. topic),
        log = self.log,
        w = {
        }
    }
    setmetatable(o, channel)

    local watcher = {}
    watcher.__index = watcher

    function watcher:change(data)
        o:publish(self, o.path, o.key, nil, data)
    end

    o.w = watcher

    return o
end

return channel
