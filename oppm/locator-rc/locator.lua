local component = require('component')
local gps = require('gps')
local positiond = require('positiond')
local sides = require('sides')
local vec3 = require('vec3')

local function round(x)
    local f = math.floor(x)

    if x - f >= 0.5 then
        return f + 1
    else
        return f
    end
end

local function validate(x, y, z)
    return type(x) == 'number'
        and type(y) == 'number'
        and type(z) == 'number'
end

function start(cfg)
    if not cfg then cfg = {} end

    local x, y, z = gps.locate(cfg.responsePort, cfg.timeout, cfg.maxTries, cfg.satellitePort)
    
    if not validate(x, y, z) then return end

    x = round(x)
    y = round(y)
    z = round(z)

    -- Try to detect facing if possible
    if not component.isAvailable('robot') then
        positiond.setPosition(x, y, z)
        return
    end

    local robot = component.robot

    -- Try to move in some direction to detect facing
    local maps = positiond.getMaps()
    local direction = nil
    local turnCount = 0
    for dirAdd = 0, 3 do
        if robot.move(sides.forward) then
            local nx, ny, nz = gps.locate(cfg.responsePort, cfg.timeout, cfg.maxTries, cfg.satellitePort)
            robot.move(sides.back)

            if not validate(nx, ny, nz) then break end

            assert(ny == y, 'the robot must move horizontally')

            nx = round(nx)
            nz = round(nz)

            local ox = nx - x
            local oz = nz - z

            assert(ox * ox + oz * oz == 1, 'the robot must move only on one axis')

            if ox > 0 then direction = maps.east
            elseif ox < 0 then direction = maps.west
            elseif oz > 0 then direction = maps.south
            elseif oz < 0 then direction = maps.north
            else error('cannot detect direction') end

            direction = direction - dirAdd

            break
        end
        robot.turn(false)
        turnCount = turnCount + 1
    end
    
    -- Turn back
    if turnCount == 1 then robot.turn(true)
    elseif turnCount == 2 then robot.turn(true) robot.turn(true)
    elseif turnCount == 3 then robot.turn(false)
    end

    positiond.setSide(maps.dirToSideMap[direction % 4])
    positiond.setPosition(vec3.new(x, y, z))
end