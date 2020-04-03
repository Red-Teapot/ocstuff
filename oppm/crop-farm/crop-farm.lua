-- OC libs
local component = require('component')
local sides = require('sides')
local event = require('event')
-- My libs
local plotly = require('plotly')
local positiond = require('positiond')
local vec3 = require('vec3')

local robot = component.robot

local args = {...}

local configFileName = args[1] or '/home/crop-farm-cfg.lua'
local cfg = dofile(configFileName)

local plot = nil

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

plot:goHome()
plot:work()
