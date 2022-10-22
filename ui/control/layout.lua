---@class ui.control.layout
---@field log hs.logger
---@field cfg ui.cfg
---@field connections table<string, table<string, any>>
---@field gates ui.preview.window[]
---@field preOrdered ui.preview.state[]
---@field workspace hs.geometry
---@field private canvas hs.canvas
local layout = {}
layout.__index = layout
layout.__name = 'layout'
layout.log = hs.logger.new('layout', 'debug')

---@return ui.control.layout
function layout:new(numCells)
    local o = {}
    setmetatable(o, self)
    return o:init(numCells)
end

function layout:init(numCells)
    self.updater = hs.timer.doEvery(1, function()
        self:reorder()
    end):start()
    self.gates = {}
    self.connections = {}
    self.canvas = hs.canvas.new(ui.screen)
        :appendElements(
            {
                type = "image",
                action = "fill",
                image = hs.image.imageFromPath(hs.configdir .. '/bg.png'),
                imageAlpha = 0.5,
                imageScaling = 'scaleToFit',
            }, {
                type = "rectangle",
                action = "fill",
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
        :level(hs.canvas.windowLevels.desktopIcon)
        :clickActivating(false)
        :behavior({
            hs.canvas.windowBehaviors.transient,
            hs.canvas.windowBehaviors.canJoinAllSpaces,
            hs.canvas.windowBehaviors.fullScreenAuxiliary
        })
        :alpha(1.0)
        :wantsLayer(true)
        :show()

    self.workspace = hs.geometry('[15,5,95,97]'):fromUnitRect(ui.screen)

    ---@type hs.geometry
    local workspace = hs.geometry.copy(self.workspace)
    workspace.x, workspace.w, workspace.h = 0, workspace.x, workspace.h/8
    for i = 1, numCells do
        local cell = hs.geometry.copy(hs.geometry(workspace))
        cell.y = cell.y + (cell.h * (i - 1))
        -- local unitCell = {
            -- x = tostring(math.floor(10000 * cell.x / ui.screen.w)/100)..'%',
            -- y = tostring(math.floor(10000 * cell.y / ui.screen.h)/100)..'%',
            -- w = tostring(math.floor(10000 * cell.w / ui.screen.w)/100)..'%',
            -- h = tostring(math.floor(10000 * cell.h / ui.screen.h)/100)..'%'
        -- }
        -- print(hs.inspect.inspect(unitCell))

        self.gates[i] = ui.preview.window:new(cell, i)
        -- self.canvas:appendElements({
            -- type = 'canvas',
            -- action = 'fill',
            -- canvas = self.gates[i]:canvas(),
            -- frame = unitCell,
        -- })
    end
    return self
end

---@param id string
---@param state ui.preview.state
---@param cfg ui.cfg
function layout:attach(id, state, cfg)
    self.log.df('new connection, %s', id)
    self.connections[id] = {state = state, cfg = cfg}
end

---@param id string
function layout:detach(id)
    self.log.df('connection\'s gone, %s', id)
    self.connections[id] = nil
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

    for i, gate in ipairs(self.gates) do
        local linkedTo = preOrdered[i]
        if linkedTo == nil then
            gate:state(ui.preview.state:new())
        elseif gate:state().id ~= linkedTo.state.id then
            gate:state(linkedTo.state)
        end
        gate:apply()
    end
end

return layout
