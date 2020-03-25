local component = require('component')
local sides = require('sides')
local math = require('math')

local dirToOffsetMap = {
    [0] = {0, -1},
    [1] = {-1, 0},
    [2] = {0, 1},
    [3] = {1, 0},
}
local dirToSideMap = {
    [0] = sides.north,
    [1] = sides.west,
    [2] = sides.south,
    [3] = sides.east,
}
local sideToDirMap = {
    [sides.north] = 0,
    [sides.west] = 1,
    [sides.south] = 2,
    [sides.east] = 3,
}
local deltaToDirMap = {
    x = {
        [-1] = sides.negx,
        [1] = sides.posx,
    },
    z = {
        [-1] = sides.negz,
        [1] = sides.posz,
    },
}

local pos = {
    x = 0,
    y = 0,
    z = 0,
    d = 0, -- 0 N, 1 W, 2 S, 3 E
}
local origMove = nil
local origTurn = nil

local rekkon = {}

function rekkon.move(dir)
    if not origMove then
        error('rekkon is not installed')
    end

    if not origMove(dir) then
        return false
    end

    if dir == sides.up then
        pos.y = pos.y + 1
    elseif dir == sides.down then
        pos.y = pos.y - 1
    elseif dir == sides.forward or dir == sides.back then
        local dx, dz = table.unpack(dirToOffsetMap[pos.d])

        if dir == sides.back then
            dx = dx * -1
            dz = dz * -1
        end

        pos.x = pos.x + dx
        pos.z = pos.z + dz
    else
        error('Wrong direction:', dir)
    end

    return true
end

function rekkon.turn(clockwise)
    if not origTurn then
        error('rekkon is not installed')
    end

    if not origTurn(clockwise) then
        return false
    end

    if clockwise then
        pos.d = (pos.d - 1) % 4
    else
        pos.d = (pos.d + 1) % 4
    end

    return true
end

function rekkon.getPosition()
    return pos.x, pos.y, pos.z
end

function rekkon.getRotation()
    return dirToSideMap[pos.d]
end

function rekkon.setPosition(x, y, z, d)
    pos.x = x
    pos.y = y
    pos.z = z
    pos.d = sideToDirMap[d]
end

function rekkon.lookAt(side)
    local dir = sideToDirMap[side]
    local deltaDir = (dir - pos.d) % 4

    if deltaDir == 0 then
        -- Do nothing
    elseif deltaDir == 1 then
        rekkon.turn(false)
    elseif deltaDir == 2 then
        rekkon.turn(false)
        rekkon.turn(false)
    elseif deltaDir == 3 then
        rekkon.turn(true)
    else
        error('Wrong delta dir')
    end
end

function rekkon.goRelative(dx, dy, dz, d, c1, c2, c3, cantMoveCallback)
    if not c1 then c1 = 'x' end
    if not c2 then c2 = 'y' end
    if not c3 then c3 = 'z' end

    local offset = {
        x = dx,
        y = dy,
        z = dz,
    }
    local order = {c1, c2, c3}

    for _, c in pairs(order) do
        local delta = offset[c]
        local deltaAbs = math.abs(delta)

        if delta ~= 0 then
            local sign = -1
            if delta > 0 then sign = 1 end

            if c == 'y' then
                for _ = 1, deltaAbs do
                    if sign == 1 then 
                        while not rekkon.move(sides.up) do
                            if cantMoveCallback then cantMoveCallback(sides.up) end
                        end
                    else 
                        while not rekkon.move(sides.down) do
                            if cantMoveCallback then cantMoveCallback(sides.down) end
                        end
                    end
                end
            elseif c == 'x' or c == 'z' then
                rekkon.lookAt(deltaToDirMap[c][sign])
                for _ = 1, deltaAbs do
                    while not rekkon.move(sides.forward) do
                        if cantMoveCallback then cantMoveCallback(sides.forward) end
                    end
                end
            else
                error('Wrong coordinate: ' .. c)
            end
        end
    end

    if d ~= nil then
        rekkon.lookAt(d)
    end
end

function rekkon.goTo(x, y, z, d, c1, c2, c3, cantMoveCallback)
    return rekkon.goRelative(x - pos.x, y - pos.y, z - pos.z, d, c1, c2, c3, cantMoveCallback)
end

function rekkon.install()
    if not origMove and not origTurn then
        origMove = component.robot.move
        origTurn = component.robot.turn

        component.robot.move = rekkon.move
        component.robot.turn = rekkon.turn
    end
end

function rekkon.uninstall()
    component.robot.move = origMove
    component.robot.turn = origTurn
end

return rekkon