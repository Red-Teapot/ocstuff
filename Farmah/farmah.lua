local sides = require('sides')
local robot = require('robot')
local os = require('os')
local event = require('event')

local rekkon = require('rekkon')

local args = {...}

local start = {
    x = args[1],
    y = args[2],
    z = args[3],
    d = sides[args[4]],
}
local cfg_name = args[5]
package.loaded[cfg_name] = nil
local cfg = require(cfg_name)

local function init()
    rekkon.install()
    rekkon.setPosition(start.x, start.y, start.z, start.d)
end

local function goHome()
    rekkon.goTo(start.x, start.y, start.z, start.d, table.unpack(cfg.goHomeCoordOrder))
end

local function goTo(x, y, z, d)
    rekkon.goTo(x, y, z, d, table.unpack(cfg.goToCropCoordOrder))
end

local function collectCrops()
    goTo(cfg.area.x, cfg.area.y, cfg.area.z, sides.south)

    local startX = cfg.area.x
    local endX = startX + cfg.area.dx - 1
    local startZ = cfg.area.z
    local endZ = startZ + cfg.area.dz - 1

    for x = startX, endX do
        local dir = ((x - startX) % 2) == 0
        local sz, ez, dz
        if dir then
            sz = startZ
            ez = endZ
            dz = 1
        else
            sz = endZ
            ez = startZ
            dz = -1
        end

        for z = sz, ez, dz do
            goTo(x, cfg.area.y, z, nil)
            robot.useDown()
        end
    end
end

local function unload()
    for slot = 1, robot.inventorySize() do
        robot.select(slot)
        robot.dropDown()
    end
end

init()

while true do
    collectCrops()
    goHome()
    unload()

    local evt = event.pull(10, 'interrupted')
    if evt then
        break
    end
end

goHome()