DB={}

---@class ui.cfg
---@field private ns string
local cfg = {}
cfg.__index = cfg
cfg.__name = 'cfg'

---@param key string
---@return ui.cfg
function cfg:new(key)
    local o = {}
    o.ns = key
    setmetatable(o, self)

    return o
end

---@param bucket string
---@return ui.cfg
function cfg:bucket(bucket)
    local o = {}
    o.ns = self.ns .. '|' .. bucket
    setmetatable(o, self)

    return o
end

---@method cfg:get
---@param key string
---@return any
function cfg:_get(key)
    print('get: ' .. self.ns .. '|' .. key)
    return hs.settings.get(self.ns .. '|' .. key)
end

---@method cfg:get
---@param key string
---@return any
function cfg:get(key)
    local cachedKey = 'cached' .. '|' .. self.ns .. '|' .. key
    local cacheValueKey = 'result' .. '|' .. self.ns .. '|' .. key
    if not DB[cachedKey] then
        DB[cacheValueKey] = self:_get(key)
        DB[cachedKey] = true
    end
    return DB[cacheValueKey]
end

---@method cfg:set
---@param key string
---@param value any
function cfg:set(key, value)
    local cachedKey = 'cached' .. '|' .. self.ns .. '|' .. key
    DB[cachedKey] = nil
    print('set: '..key)
    hs.settings.set(self.ns .. '|' .. key, value)
end

---@method cfg:add
---@param key string
---@param value number
function cfg:add(key, value)
    local v = self:get(key)
    if v == nil then
        v = 0
    end
    self:set(key, v + value)
end

---@method cfg:inc
---@param key string
function cfg:event(key)
    local v = self:get(key)
    if v == nil then
        v = {}
    end
    local now = os.time()
    table.insert(v, 1, { value = 1, time = now })
    while #v > 100 do
        table.remove(v, #v)
    end
    self:set(key, v)
end

---@method cfg:count
---@param key string
---@param delta number
---@return number
function cfg:count(key, delta)
    local v = self:get(key)
    if v == nil then
        return 0
    end
    local now = os.time()
    local count = 0
    for _, item in ipairs(v) do
        if now - item.time < delta then
            count = count + item.value
        else
            break
        end
    end
    return count
end

return cfg
