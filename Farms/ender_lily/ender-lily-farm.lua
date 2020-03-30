-- OC libs
local component = require('component')
local sides = require('sides')
local event = require('event')
-- My libs
local utils = require('utils')
local navlib = require('navlib')
local plotly = require('plotly')
local vec3 = require('vec3')

local robot = component.robot
local inv = component.inventory_controller
local geolyzer = component.geolyzer

local cfg = utils.rerequire('ender-lily-farm-cfg')

local nav = nil
local plot = nil

local function plantLily()
    local stack = inv.getStackInInternalSlot()
    local foundSeed = stack and (stack.name == cfg.seedItemName)
    if not foundSeed then
        for slot = 1, robot.inventorySize() do
            stack = inv.getStackInInternalSlot(slot)
            if stack and (stack.name == cfg.seedItemName) then
                robot.select(slot)
                foundSeed = true
                break
            end
        end
    end

    if foundSeed then
        robot.place(sides.down)
    end
end

local function plotAction()
    local info = geolyzer.analyze(sides.down)

    if not info or info.name == 'minecraft:air' then
        plantLily()
    elseif info.name == cfg.seedBlockName then
        if info.growth == 1 then
            robot.swing(sides.down)
            plantLily()
        end
    else
        print('Unexpected block at '..tostring(nav:getPosition())..': '..info.name)
    end
end

local function betweenPlotAction()
    plot:goHome()
    local dropoffSide = sides[cfg.dropoffChestSide]
    if dropoffSide ~= sides.up and dropoffSide ~= sides.down then
        nav:look(dropoffSide)
        dropoffSide = sides.forward
    end

    for slot = 1, robot.inventorySize() do
        local stack = inv.getStackInInternalSlot(slot)
        if stack and stack.name == cfg.pearlItemName then
            robot.select(slot)
            robot.drop(dropoffSide)
        end
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

nav = navlib.new(plotCfg.home.pos, plotCfg.home.facing)
plotCfg.nav = nav
plot = plotly.new(plotCfg)

plot:work()
