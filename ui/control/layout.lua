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
function layout:    new(numCells)
    local o = {}
    setmetatable(o, self)
    o.updater = hs.timer.doEvery(15, function() o:reorder() end):start()
    o.gates = {}
    o.connections = {}
    o.canvas = hs.canvas.new(ui.screen)
        :appendElements(
            { action = "build", padding = 0, type = "rectangle" },
            { action = "clip", frame={x='15%', y='5%', w='83%', h='93%'}, type = "rectangle", reversePath = true},
            {
                type = "image",
                action = "fill",
                image = hs.image.imageFromPath(hs.configdir .. '/bg.png'),
                imageAlpha = 0.5,
                imageScaling = 'scaleToFit'
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
                compositeRule = 'sourceOver',
            }
        )
        :level(hs.canvas.windowLevels.floating)
        :clickActivating(false)
        :behavior({
            hs.canvas.windowBehaviors.transient,
            hs.canvas.windowBehaviors.canJoinAllSpaces,
            hs.canvas.windowBehaviors.fullScreenAuxiliary
        })
        :wantsLayer(false)
        :alpha(1.0)
        :show()

    o.workspace = hs.geometry(o.canvas:elementBounds(2))

    ---@type hs.geometry
    local workspace = hs.geometry.copy(o.workspace)
    workspace.x, workspace.w, workspace.h = 0, workspace.x, workspace.h/8
    for i = 1, numCells do
        local cell = hs.geometry.copy(hs.geometry(workspace))
        cell.y = cell.y + (cell.h * (i - 1))
        o.gates[i] = ui.preview.window:new(cell):show()
    end
    return o
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

function layout:reorder()
    local locked = {}
    local ready = {}
    local preOrdered = {}
    for _, connection in pairs(self.connections) do
        if connection.cfg:get('locked') then
            table.insert(locked, connection)
        else
            table.insert(ready, connection)
        end
    end

    -- table.sort(locked, function(v1, v2)
    --     return (locked[v1]).cfg:get('locked.date') < v2.cfg:get('locked.date')
    -- end)
    -- table.sort(ready)


    -- table.sort(locked)
    hs.fnutils.concat(preOrdered, locked)
    -- table.sort(ready)
    hs.fnutils.concat(preOrdered, ready)

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
