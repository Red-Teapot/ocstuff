local math = require('math')
local component = require('component')
local sides = require('sides')

local vec3 = require('vec3')

local maps = {
    dirToOffsetMap = {
        [0] = vec3.new(0, 0, -1),
        [1] = vec3.new(-1, 0, 0),
        [2] = vec3.new(0, 0, 1),
        [3] = vec3.new(1, 0, 0),
    },
    dirToSideMap = {
        [0] = sides.north,
        [1] = sides.west,
        [2] = sides.south,
        [3] = sides.east,
    },
    sideToDirMap = {
        [sides.north] = 0,
        [sides.west] = 1,
        [sides.south] = 2,
        [sides.east] = 3,
    },
    deltaToDirMap = {
        x = {
            [-1] = sides.negx,
            [1] = sides.posx,
        },
        z = {
            [-1] = sides.negz,
            [1] = sides.posz,
        },
    },
    north = 0,
    west = 1,
    south = 2,
    east = 3,
}

local state = {
    position = vec3.new(),
    dir = 0,
    robotMove = nil,
    robotTurn = nil,
}

local positiond = {}

function positiond.getMaps()
    return maps
end

function positiond.setPosition(position)
    assert(vec3.isVec3(position), 'invalid position')

    state.position = position
end

function positiond.getPosition()
    return state.position
end

function positiond.setSide(side)
    assert(type(side) == 'number', 'invalid side')
    assert(maps.sideToDirMap[side] ~= nil, 'invalid side')

    state.dir = maps.sideToDirMap[side]
end

function positiond.getSide()
    return maps.dirToSideMap[state.dir]
end

function positiond.move(side)
    if not state.robotMove(side) then
        return false
    end

    local offset = vec3.new(0, 0, 0)
    if side == sides.up then
        offset = vec3.new(0, 1, 0)
    elseif side == sides.down then
        offset = vec3.new(0, -1, 0)
    elseif side == sides.forward or side == sides.back then
        offset = maps.dirToOffsetMap[state.dir]

        if side == sides.back then
            offset = -offset
        end
    else
        error('Wrong side: '..side)
    end

    state.position = state.position + offset

    return true
end

function positiond.turn(clockwise)
    if not state.robotTurn(clockwise) then
        return false
    end

    local newDir = state.dir
    if clockwise then
        newDir = newDir - 1
    else
        newDir = newDir + 1
    end
    newDir = newDir % 4
    state.dir = newDir

    return true
end

function positiond.init()
    if state.robotMove == nil then
        state.robotMove = component.robot.move
        component.robot.move = positiond.move
    end

    if state.robotTurn == nil then
        state.robotTurn = component.robot.turn
        component.robot.turn = positiond.turn
    end
end

function positiond.dispose()
    if state.robotMove ~= nil then
        component.robot.move = state.robotMove
        state.robotMove = nil
    end

    if state.robotTurn ~= nil then
        component.robot.turn = state.robotTurn
        state.robotTurn = nil
    end
end

function positiond.look(side)
    local dir = maps.sideToDirMap[side]
    local deltaDir = (dir - state.dir) % 4

    if deltaDir == 0 then
        return true
    elseif deltaDir == 1 then
        return positiond.turn(false)
    elseif deltaDir == 2 then
        return positiond.turn(false) and positiond.turn(false)
    elseif deltaDir == 3 then
        return positiond.turn(true)
    else
        error('Wrong delta dir, this should never happen')
    end
end

function positiond.goRelative(offset, facing, swizzle, obstacleCallback)
    assert(vec3.isVec3(offset), 'invalid offset')

    if not swizzle then
        swizzle = 'xyz'
    end

    for i = 1, #swizzle do
        local c = swizzle:sub(i, i)
        local distance = math.abs(offset[c])
        local sign = 1
        if offset[c] < 0 then sign = -1 end
        local moveSide = nil

        if c == 'y' then
            moveSide = sides.up

            if sign < 0 then
                moveSide = sides.down
            end
        elseif c == 'x' or c == 'z' then
            if distance > 0 then
                positiond.look(maps.deltaToDirMap[c][sign])
            end

            moveSide = sides.forward
        else
            error("Wrong coordinate: "..c)
        end

        for _ = 1, distance do
            while component.robot.detect(moveSide) do
                if obstacleCallback then obstacleCallback(moveSide) end
            end
            positiond.move(moveSide)
        end
    end

    if facing ~= nil then
        positiond.look(facing)
    end
end

function positiond.goAbsolute(position, facing, swizzle, obstacleCallback)
    assert(vec3.isVec3(position), 'invalid position')

    return positiond.goRelative(position - state.position, facing, swizzle, obstacleCallback)
end

return positiond