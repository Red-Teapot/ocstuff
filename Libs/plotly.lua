local vec3 = require('vec3')
local nav = require('nav')
local utils = require('utils')

local plotlymeta = {}
local plotly = {}

function plotlymeta:__index(idx)
    return plotlymeta[idx]
end

function plotlymeta:goHome()
    self.nav:goAbsolute(self.home.pos, nil, self.home.swizzle, self.obstacleCallback)
end

function plotlymeta:goTo(pos, facing, swizzle)
    if not swizzle then
        swizzle = self.swizzle
    end

    self.nav:goAbsolute(pos, facing, swizzle, self.obstacleCallback)
end

function plotlymeta:getNav()
    return self.nav
end

function plotlymeta:work()
    self:goTo(self.plot.pos)

    local startX = self.plot.pos.x
    local endX = startX + self.plot.sizeX - utils.sign(self.plot.sizeX)
    local dx = utils.sign(endX - startX)
    local y = self.plot.pos.y
    local startZ = self.plot.pos.z
    local endZ = startZ + self.plot.sizeZ -  utils.sign(self.plot.sizeZ)

    while self.doWork do
        for x = startX, endX, dx do
            local sz = startZ
            local ez = endZ
            if (x - startX) % 2 == 1 then
                sz = endZ
                ez = startZ
            end
            local dz = utils.sign(ez - sz)

            for z = sz, ez, dz do
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

function plotly.new(config, pos, facing)
    local plot = {
        obstacleCallback = nil,
        swizzle = 'xyz',
        plotAction = nil,
        betweenPlotAction = nil,
        
        nav = nil,
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

    utils.merge(plot, config)

    if plot.nav == nil then
        plot.nav = nav.new(pos, facing)
    end

    setmetatable(plot, plotlymeta)

    return plot
end

return plotly