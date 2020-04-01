-- OC libs
local component = require('component')
local sides = require('sides')
local event = require('event')
-- My libs
local plotly = require('plotly')
local positiond = require('positiond')
local vec3 = require('vec3')
local gpslib = require('gpslib')

local robot = component.robot

local configFileName = 'crops-farm-cfg'
package.loaded[configFileName] = nil
local cfg = require(configFileName)

local plot = nil

local function round(x)
    local f = math.floor(x)

    if x - f >= 0.5 then
        return f + 1
    else
        return f
    end
end

local function plotAction()
    robot.use(sides.down)
end

local function betweenPlotAction()
    plot:goHome()
    local dropoffSide = sides[cfg.dropoffChestSide]
    if dropoffSide ~= sides.up and dropoffSide ~= sides.down then
        positiond.look(dropoffSide)
        dropoffSide = sides.forward
    end

    for slot = 1, robot.inventorySize() do
        robot.select(slot)
        robot.drop(dropoffSide)
    end

    local evt = event.pull(cfg.idleTimeout, 'interrupted')
    if evt then
        print('Terminated by user')
        plot:stop()
    end
end

local plotCfg = {
    home = {
        pos = vec3.from(cfg.home),
        facing = sides[cfg.home.facing],
        swizzle = cfg.home.swizzle,
    },
    plot = {
        pos = vec3.from(cfg.plot),
        sizeX = cfg.plot.sizeX,
        sizeZ = cfg.plot.sizeZ,
        swizzle = cfg.plot.swizzle,
    },
    energyThreshold = cfg.energyThreshold,

    plotAction = plotAction,
    betweenPlotAction = betweenPlotAction,
}

plot = plotly.new(plotCfg)

if cfg.useGPS then
    local x, y, z = gpslib.locate(nil, 0.2, 10)
    if x ~= nil then
        print('Got position via GPS', x, y, z)
        local side = nil

        robot.move(sides.forward)
        local x2, y2, z2 = gpslib.locate(nil, 0.2, 10)
        print('Offset position', x2, y2, z2)
        if x2 ~= nil then
            local dx = x2 - x
            local dz = z2 - z

            print('Offset', dx, dz)

            if dx > 0.5 then side = sides.east
            elseif dx < -0.5 then side = sides.west
            elseif dz > 0.5 then side = sides.south
            elseif dz < -0.5 then side = sides.north
            end
        end
        robot.move(sides.back)

        positiond.setPosition(vec3.new(round(x), round(y), round(z)))
        if side ~= nil then
            print('Got facing via GPS', sides[side])
            positiond.setSide(side)
        end
    end
end

plot:goHome()
plot:work()
