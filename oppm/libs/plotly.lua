local computer = require('computer')

local positiond = require('positiond')
local vec3 = require('vec3')

local function sign(x)
    if x > 0 then return 1
    elseif x == 0 then return 0
    else return -1 end
end

local function merge(dst, src)
    for key, value in pairs(src) do
        local t = type(value)

        if t == 'table' then
            if not dst[key] then
                dst[key] = {}
            end

            merge(dst[key], value)
            setmetatable(dst[key], getmetatable(value))
        elseif t == 'nil' then
            -- Do nothing
        else
            dst[key] = value
        end
    end
end

local plotlymeta = {}
local plotly = {}

function plotlymeta:__index(idx)
    return plotlymeta[idx]
end

function plotlymeta:goHome()
    positiond.goAbsolute(self.home.pos, nil, self.home.swizzle, self.obstacleCallback)
end

function plotlymeta:goTo(pos, facing, swizzle)
    if not swizzle then
        swizzle = self.swizzle
    end

    positiond.goAbsolute(pos, facing, swizzle, self.obstacleCallback)
end

function plotlymeta:work()
    self:goTo(self.plot.pos)

    local startX = self.plot.pos.x
    local endX = startX + self.plot.sizeX - sign(self.plot.sizeX)
    local dx = sign(endX - startX)
    local y = self.plot.pos.y
    local startZ = self.plot.pos.z
    local endZ = startZ + self.plot.sizeZ -  sign(self.plot.sizeZ)

    while self.doWork do
        for x = startX, endX, dx do
            local sz = startZ
            local ez = endZ
            if (x - startX) % 2 == 1 then
                sz = endZ
                ez = startZ
            end
            local dz = sign(ez - sz)

            for z = sz, ez, dz do
                if computer.energy() < self.energyThreshold then
                    if self.lowEnergyCallback ~= nil then
                        self.lowEnergyCallback()
                    else
                        self:goHome()
                        computer.shutdown()
                    end
                end

                self:goTo(vec3.new(x, y, z), nil, self.plot.swizzle)

                if self.plotAction then
                    self.plotAction()
                end
            end
        end

        if self.betweenPlotAction then
            self.betweenPlotAction()
        end
    end
end

function plotlymeta:stop()
    self.doWork = false
end

function plotly.new(config)
    local plot = {
        obstacleCallback = nil,
        swizzle = 'xyz',
        plotAction = nil,
        betweenPlotAction = nil,
        energyThreshold = 2000,
        lowEnergyCallback = nil,
        
        doWork = true,

        home = {
            pos = vec3.new(0, 0, 0),
            swizzle = 'xyz',
        },
        plot = {
            pos = vec3.new(0, 0, 0),
            swizzle = 'xyz',
            sizeX = 0,
            sizeZ = 0,
        },
    }

    merge(plot, config)

    setmetatable(plot, plotlymeta)

    return plot
end

return plotly