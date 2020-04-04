-- OC libs
local component = require('component')
local sides = require('sides')
local event = require('event')
-- My libs
local positiond = require('positiond')
local plotly = require('plotly')
local vec3 = require('vec3')

local robot = component.robot
local inv = component.inventory_controller
local geolyzer = component.geolyzer

local args = {...}

local configFileName = args[1] or '/home/tree-farm-cfg.lua'
local cfg = dofile(configFileName)

local plot = nil

local suck = function(side)
    robot.suck(side)
end
if component.isAvailable('tractor_beam') then
    suck = function(_)
        component.tractor_beam.suck()
    end
end

local function obstacleCallback(side)
    robot.swing(side)
end

local function plantTree()
    local stack = inv.getStackInInternalSlot()
    local foundSapling = stack and (stack.name == cfg.saplingItemName)
    if not foundSapling then
        for slot = 1, robot.inventorySize() do
            stack = inv.getStackInInternalSlot(slot)
            if stack and (stack.name == cfg.saplingItemName) then
                robot.select(slot)
                foundSapling = true
                break
            end
        end
    end

    if foundSapling then
        robot.place(sides.down)
    end
end

local function cutTree()
    local initialPos = positiond.getPosition()

    while true do
        local info = geolyzer.analyze(sides.up)
        if not info or info.name ~= cfg.woodBlockName then
            break
        end

        robot.swing(sides.up)
        suck(sides.up)
        robot.move(sides.up)
    end

    positiond.goAbsolute(initialPos, nil, cfg.plot.swizzle, obstacleCallback)

    robot.swing(sides.down)
    suck(sides.down)
    plantTree()
end

local function plotAction()
    suck(sides.down)

    local info = geolyzer.analyze(sides.down)

    if not info or info.name == 'minecraft:air' then
        plantTree()
    elseif info.name == cfg.woodBlockName then
        cutTree()
    end
end

local function betweenPlotAction()
    plot:goHome()
    local dropoffSide = sides[cfg.dropoffChestSide]
    if dropoffSide ~= sides.up and dropoffSide ~= sides.down then
        positiond.look(dropoffSide)
        dropoffSide = sides.forward
    end

    for slot = 1, robot.inventorySize() do
        local stack = inv.getStackInInternalSlot(slot)
        if stack and stack.name ~= cfg.saplingItemName then
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
    obstacleCallback = obstacleCallback,
}

plot = plotly.new(plotCfg)

print('Waiting for termination')
local evt = event.pull(10, 'interrupted')
if evt then return end
print('Continuing')

plot:goHome()
plot:work()
