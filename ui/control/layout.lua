---@class ui.control.layout
---@field log hs.logger
---@field cfg ui.cfg
---@field connections table<string, table<string, any>>
---@field gates ui.preview.window[]
---@field preOrdered ui.preview.state[]
---@field workspace hs.geometry
---@field private canvas hs.canvas
---@field private canvas2 hs.canvas
local layout = {}
layout.__index = layout
layout.__name = 'layout'
layout.log = hs.logger.new('layout', 'info')

---@return ui.control.layout
function layout:new(numCells)
    local o = {}
    setmetatable(o, self)
    self.workspace = hs.geometry('[16,5,97,97]'):fromUnitRect(ui.screen)
    return o:init(numCells)
end

function snap()
end

function layout:init(numCells)
    self.gates = {}
    self.connections = {}
    self.preOrdered = {}
    self.dirty = false
    self.hub = ui.events.new('root', 'window', 'info')
    self.empty = {state = ui.state:new()}


    local frame = hs.geometry('[0,5,15,97]'):fromUnitRect(ui.screen)

    self.canvas = hs.canvas.new(frame)
    :appendElements(
        {
            type = "image",
            action = "fill",
            image = hs.image.imageFromPath(hs.configdir .. '/bg.png'),
            imageAlpha = 0.4,
            imageScaling = 'scaleToFit',
        }, {
            type = "rectangle",
            fillColor = { white = 0.1, alpha = 0.7 },
            frame = { x = "0%", y = "0%", h = "100%", w = "100%" },
            padding = 0,
            fillGradient = "radial",
            fillGradientAngle = 45,
            fillGradientColors = {
                { black = 0.1, alpha = 0.8 },
                { black = 0.9, alpha = 0.5 },
                { black = 0.5, alpha = 0.3 },
                { black = 0.9, alpha = 0.5 },
                { black = 0.1, alpha = 0.9 },
            },
            fillGradientCenter = { x = -1.0, y = -1.0 },
        }
    )
    :behaviorAsLabels({
        "transient",
        "canJoinAllSpaces",
        "ignoresCycle",
        "fullScreenAuxiliary",
        "fullScreenAllowsTiling"
    })
    :clickActivating(false)
    :canvasMouseEvents(false, false, false, false)
    :alpha(0.5)
    :wantsLayer(true)


    ---@type hs.geometry
    local workspace = hs.geometry.copy(self.workspace)
    workspace.x, workspace.w, workspace.h = self.canvas:frame().x, workspace.x, workspace.h / 8
    for i = 1, numCells do
        local cell = hs.geometry.copy(hs.geometry(workspace))
        cell.y = cell.y + (cell.h * (i - 1))
        cell.w = cell.h * ui.preview.size.aspect


        local id = i
        local gate = ui.preview.window:new(id, self.hub, {x=cell.x, y=cell.y, w=cell.w, h=cell.h})
        gate:show()
        self.gates[i] = gate
    end

    self.canvas:show():level(hs.canvas.windowLevels.dock)

    self.updater = hs.timer.doEvery(1, function()
        self:reorder()
        collectgarbage('step')
    end, true)
    hs.timer.doAfter(0.5, function()
        self:reorder()
    end)

    return self
end

---@param id string
---@param state ui.preview.state
---@param cfg ui.cfg
function layout:attach(id, state, cfg)
    self.log.df('new connection, %s', id)
    self.connections[id] = { state = state, cfg = cfg }
    self:reorder()
    self.dirty = true
end

---@param id string
function layout:detach(id)
    self.log.df('connection\'s gone, %s', id)
    self.connections[id] = nil
    self:reorder()
    self.dirty = true
end

function layout:cellSize()
    ---@type hs.geometry
    local f = hs.geometry.copy(self.workspace)
    f.w = 276
    return f
end

function layout:reorder()
    ---@param cfg ui.cfg
    local function fetureVec(cfg)
        local fatures = {}
        if cfg:get('locked') then table.insert(fatures, 1) else table.insert(fatures, 0) end
        table.insert(fatures, cfg:count('flow', 3600))
        table.insert(fatures, cfg:count('focused', 600))
        table.insert(fatures, cfg:count('flow', 24 * 3600))
        return fatures
    end

    ---@param f1 number[]
    ---@param f2 number[]
    local function compare(f1, f2)
        for i = 1, #f1 do
            if f1[i] ~= f2[i] then return f1[i] > f2[i] end
        end
        return false
    end

    local preOrdered = {}
    for _, connection in pairs(self.connections) do
        table.insert(preOrdered, connection)
    end

    table.sort(preOrdered, function(v1, v2)
        local f1 = fetureVec(v1.cfg)
        local f2 = fetureVec(v2.cfg)
        return compare(f1, f2)
    end)

    self.preOrdered = preOrdered
    for i, gate in ipairs(self.gates) do
        local linkedTo = self.preOrdered[i] or self.empty
        if gate:state().id ~= linkedTo.state.id then
            if gate:state() ~= nil then
                gate:state():onDetach()
                gate:apply()
            end
            gate:state(linkedTo.state)
            gate:state():onAttach(function() gate:apply() end, i)
            gate:apply()
        end
    end
end

return layout
