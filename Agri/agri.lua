-- Reload rekkon in case it changed
package.loaded['rekkon'] = nil

-- Require necessary libraries
local sides = require('sides')
local component = require('component')
local serialization = require('serialization')
local os = require('os')
local event = require('event')

local rekkon = require('rekkon')
local agri_stat = require('agri-stat')

local geolyzer = component.geolyzer
local inventory = component.inventory_controller
local robot = component.robot

-- Read CLI args
local args = {...}

-- Init some variables
local start = {
    x = args[1],
    y = args[2],
    z = args[3],
    d = sides[args[4]],
}
local cfg_name = args[5]
package.loaded[cfg_name] = nil
local cfg = require(cfg_name)

-- Seeds states
local upgradeStates = {}
local plantsToUpgrade = {}
local garbageItems = {}
local whitelistedItems = {}

local replaceQueue = {}
local allocatedForReplaceSlots = {}

local function init()
    rekkon.install()
    rekkon.setPosition(start.x, start.y, start.z, start.d)

    for _, point in pairs(cfg.upgrade) do
        plantsToUpgrade[point.crop] = true
    end

    for _, item in pairs(cfg.garbage) do
        garbageItems[item] = true
    end

    for _, item in pairs(cfg.itemsWhitelist) do
        whitelistedItems[item] = true
    end
end

local function goToStart()
    rekkon.goTo(start.x, start.y, start.z, start.d, table.unpack(cfg.goHomeCoordOrder))
end

local function getBlockType(info)
    if info.name == 'AgriCraft:crops' then
        if info.maxGrowth ~= nil then
            return 'known_crop'
        end

        return 'unknown_crop'
    elseif info.name == 'minecraft:air' then
        return 'air'
    else
        return 'unknown'
    end
end

local function placeCropsticks(useDouble)
    robot.select(cfg.cropSlot)
    inventory.equip()
    robot.use(sides.down)

    if not useDouble then
        -- The robot places double cropsticks
        -- so we click again to make them single
        robot.use(sides.down)
    end

    inventory.equip()
end

local function refreshTile(info, useDoubleCropsticks)
    local bType = getBlockType(info)

    if bType == 'unknown_crop' then -- Weeds or non-analyzed seeds
        -- Break cropsticks and replace it
        robot.swing(sides.down)
        placeCropsticks(useDoubleCropsticks)
    elseif bType == 'air' then -- No cropsticks
        placeCropsticks(useDoubleCropsticks)
    end
end

local function scanSurroundingUpgradePlants()
    local result = {}

    for _, side in pairs({sides.north, sides.west, sides.south, sides.east}) do
        rekkon.lookAt(side)
        rekkon.move(sides.forward)

        local info = geolyzer.analyze(sides.down)
        if getBlockType(info) == 'known_crop' then
            result[side] = agri_stat.from(info)
        end

        rekkon.move(sides.back)
    end

    return result
end

local function tryEnqueueSeedReplace(info, slot)
    if not plantsToUpgrade[info.name] then
        return false
    end

    local seedStat = agri_stat.from(info.agricraft)

    for i, state in pairs(upgradeStates) do
        if cfg.upgrade[i].crop == info.name then
            local minStat = nil
            local minStatSide = nil

            for side, stat in pairs(state) do
                if not minStat then
                    minStat = stat
                    minStatSide = side
                elseif stat < minStat then
                    minStat = stat
                    minStatSide = side
                end
            end

            if seedStat > minStat then
                if not replaceQueue[i] then
                    replaceQueue[i] = {}
                end

                if not replaceQueue[i][minStatSide] then
                    replaceQueue[i][minStatSide] = slot
                    allocatedForReplaceSlots[slot] = true
                    return true
                end
            end
        end
    end

    return false
end

local function sortInventory()
    for slot = 1, robot.inventorySize() do
        local info = inventory.getStackInInternalSlot(slot)

        if info then
            robot.select(slot)
            if garbageItems[info.name] then
                robot.drop(sides.down, 64)
            elseif info.name:lower():match('seed') and not info.agricraft then
                inventory.dropIntoSlot(sides.front, 1, 64)
                os.sleep(1.5)
                inventory.suckFromSlot(sides.front, 1, 64)

                local info = inventory.getStackInInternalSlot(slot)

                if not tryEnqueueSeedReplace(info, slot) then
                    robot.drop(sides.down)
                end
            end
        end
    end

    -- Discard all items except whitelist
    for slot = 1, robot.inventorySize() do
        local info = inventory.getStackInInternalSlot(slot)

        if info then
            robot.select(slot)
            if info.name == cfg.cropsItem and robot.space(cfg.cropSlot) > 0 and slot ~= cfg.cropSlot then
                robot.transferTo(cfg.cropSlot, robot.space(cfg.cropSlot))
                robot.drop(sides.down)
            elseif not whitelistedItems[info.name] and not allocatedForReplaceSlots[slot] then
                robot.drop(sides.down)
            end
        end
    end

    -- Try to refill cropsticks if needed
    if robot.space(cfg.cropSlot) > 0 then
        local missingCrops = robot.space(cfg.cropSlot)

        for slot = 1, inventory.getInventorySize(sides.down) do
            local info = inventory.getStackInSlot(sides.down, slot)

            if info and info.name == cfg.cropsItem then
                robot.select(cfg.cropSlot)

                inventory.suckFromSlot(sides.down, slot, missingCrops)

                missingCrops = robot.space(cfg.cropSlot)
                
                if missingCrops <= 0 then
                    break
                end
            end
        end
    end
end

local function loop()
    for i, point in pairs(cfg.upgrade) do
        rekkon.goTo(point.x, point.y + 1, point.z, nil, table.unpack(cfg.goToCropCoordOrder))

        local info = geolyzer.analyze(sides.down)

        refreshTile(info, true)

        if not upgradeStates[i] then
            local surround = scanSurroundingUpgradePlants()
            if #surround > 0 then
                upgradeStates[i] = surround
            end
        end

        if replaceQueue[i] then
            for side, slot in pairs(replaceQueue[i]) do
                rekkon.lookAt(side)
                rekkon.move(sides.forward)

                local newStat = inventory.getStackInInternalSlot(slot)
                newStat = agri_stat.from(newStat.agricraft)

                robot.use(sides.down) -- Rakes
                robot.select(slot) -- New seed
                inventory.equip()
                robot.use(sides.down)
                inventory.equip() -- Equip rakes back

                rekkon.move(sides.back)
                upgradeStates[i][side] = newStat
                allocatedForReplaceSlots[slot] = nil
            end
        end
        replaceQueue[i] = nil
    end

    for _, point in pairs(cfg.cross) do
        rekkon.goTo(point.x, point.y + 1, point.z, nil, table.unpack(cfg.goToCropCoordOrder))

        local info = geolyzer.analyze(sides.down)

        refreshTile(info, true)
    end

    goToStart()
    rekkon.lookAt(sides[cfg.analyzerSide])

    sortInventory()
end

-- Main logic
init()

while true do
    loop()

    local evt = event.pull(10, 'interrupted')
    if evt then
        break
    end
end

goToStart()
