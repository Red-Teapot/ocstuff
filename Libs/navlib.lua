local math = require('math')
local component = require('component')
local sides = require('sides')
local fs = require('filesystem')

local vec3 = require('vec3')

local static = {
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
    persistFile = '/opt/redteapot-navlib.dat',
}

local navmeta = {}
local navlib = {}

function navmeta:__index(idx)
    return navmeta[idx]
end

function navmeta:dispose()
    component.robot.move = self.origMove
    component.robot.turn = self.origTurn
    self = nil
end

function navmeta:setPosition(pos)
    assert(vec3.isVec3(pos), 'invalid position')

    self.pos = pos
end

function navmeta:setFacing(facing)
    self.dir = static.sideToDirMap[facing]
end

function navmeta:getPosition()
    return self.pos
end

function navmeta:getFacing()
    return static.dirToSideMap[self.dir]
end

function navmeta:move(side)
    local oldPos = self.pos

    local offset = vec3.new(0, 0, 0)
    if side == sides.up then
        offset = vec3.new(0, 1, 0)
    elseif side == sides.down then
        offset = vec3.new(0, -1, 0)
    elseif side == sides.forward or side == sides.back then
        offset = static.dirToOffsetMap[self.dir]

        if side == sides.back then
            offset = -offset
        end
    else
        error('Wrong side: '..side)
    end

    local newPos = self.pos + offset

    -- Try to compensate for turning the robot off while moving
    if self.doPersist then
        self:save(newPos, self.dir)
    end

    if not self.origMove(side) then
        -- Cancel the movement
        if self.doPersist then
            self:save(oldPos, self.dir)
        end

        return false
    end

    self.pos = newPos

    return true
end

function navmeta:turn(clockwise)
    local oldDir = self.dir
    local newDir = (self.dir + 1) % 4
    if clockwise then
        newDir = (self.dir - 1) % 4
    end

    -- Try to compensate for turning the robot off while turning
    if self.doPersist then
        self:save(self.pos, newDir)
    end

    if not self.origTurn(clockwise) then
        -- Cancel the turn
        if self.doPersist then
            self:save(self.pos, oldDir)
        end

        return false
    end

    self.dir = newDir

    return true
end

function navmeta:look(facing)
    local dir = static.sideToDirMap[facing]
    local deltaDir = (dir - self.dir) % 4

    if deltaDir == 0 then
        return true
    elseif deltaDir == 1 then
        return self:turn(false)
    elseif deltaDir == 2 then
        return self:turn(false) and self:turn(false)
    elseif deltaDir == 3 then
        return self:turn(true)
    else
        error('Wrong delta dir, this should never happen')
    end
end

function navmeta:goRelative(offset, facing, swizzle, obstacleCallback)
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
                self:look(static.deltaToDirMap[c][sign])
            end

            moveSide = sides.forward
        else
            error("Wrong coordinate: "..c)
        end

        for _ = 1, distance do
            while not self:move(moveSide) do
                if obstacleCallback then obstacleCallback(moveSide) end
            end
        end
    end

    if facing ~= nil then
        self:look(facing)
    end
end

function navmeta:goAbsolute(position, facing, swizzle, obstacleCallback)
    assert(vec3.isVec3(position), 'invalid position')

    return self:goRelative(position - self.pos, facing, swizzle, obstacleCallback)
end

function navmeta:load()
    if fs.exists(static.persistFile) then
        local file = io.open(static.persistFile, 'r')
        if not file then return end

        local x = file:read("*n")
        local y = file:read("*n")
        local z = file:read("*n")
        local d = file:read("*n")
        if x ~= nil and y ~= nil and z ~= nil and d ~= nil then
            self.pos = vec3.new(x, y, z)
            self.dir = d
        end

        file:close()
    end
end

function navmeta:save(pos, dir)
    local file = io.open(static.persistFile, 'w')
    if not file then return end

    file:write(tostring(pos.x)..' ')
    file:write(tostring(pos.y)..' ')
    file:write(tostring(pos.z)..' ')
    file:write(tostring(dir))

    file:close()
end

function navlib.new(position, facing, doPersist)
    local res = {
        pos = vec3.new(0, 0, 0),
        dir = 0,
        origMove = component.robot.move,
        origTurn = component.robot.turn,
        doPersist = doPersist,
    }

    setmetatable(res, navmeta)

    if doPersist then
        fs.makeDirectory(fs.path(static.persistFile))
    end

    if position ~= nil then res:setPosition(position) end
    if facing ~= nil then res:setFacing(facing) end

    component.robot.move = function(side)
        return res:move(side)
    end

    component.robot.turn = function(clockwise)
        return res:turn(clockwise)
    end

    res:load()

    return res
end

return navlib