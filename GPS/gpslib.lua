local component = require('component')
local event = require('event')
local math = require('math')
local os = require('os')
local vec3 = require('vec3')

local ser = require('serialization')

local modem = component.modem

local cfg = {
    satellitePort = 42,
    defaultResponsePort = 42,
}

local gpslib = {}

function gpslib.locate(responsePort, timeout, maxTries)
    if not responsePort then responsePort = cfg.defaultResponsePort end
    if not timeout then timeout = 2 end
    if not maxTries then maxTries = 2 end

    local oldStrength = modem.getStrength()
    modem.setStrength(1000000)

    modem.broadcast(cfg.satellitePort, 'gps-wakeup')

    local responses = {}
    local responseCount = 0 -- Because tables have no simple way to get item count

    local onResponse = function(_, _, remoteAddress, _, distance, satX, satY, satZ)
        if not responses[remoteAddress] then
            responses[remoteAddress] = {
                distance = distance,
                x = satX,
                y = satY,
                z = satZ,
            }
            responseCount = responseCount + 1
        end
    end
    event.listen('modem_message', onResponse)
    modem.open(responsePort)

    for _ = 1, maxTries do
        modem.broadcast(cfg.satellitePort, responsePort)
        os.sleep(timeout)
        if responseCount >= 3 then
            break
        end
    end

    event.ignore('modem_message', onResponse)
    modem.close(responsePort)
    modem.setStrength(oldStrength)

    if responseCount < 3 then
        return nil, 'not enough satellite responses'
    end

    local responsesSorted = {}
    for _, resp in pairs(responses) do
        responsesSorted[#responsesSorted + 1] = resp
    end
    table.sort(responsesSorted, function(a, b)
        return a.z < b.z
    end)

    local a = vec3.from(responsesSorted[1])
    local ra = responsesSorted[1].distance
    local b = vec3.from(responsesSorted[2])
    local rb = responsesSorted[2].distance
    local c = vec3.from(responsesSorted[3])
    local rc = responsesSorted[3].distance

    -- See https://en.wikipedia.org/wiki/True_range_multilateration#Three_Cartesian_dimensions,_three_measured_slant_ranges
    -- We convert some coordinates so x corresponds to ab, y corresponds to abOrthogonal
    local ab = b - a
    local ac = c - a
    local U = ab:lengthEuclid()
    ab = ab / U

    local abOrthogonal = vec3.new(-ab.z, ab.y, ab.x)

    local Vx = ab:dot(ac)
    local Vz = abOrthogonal:dot(ac)
    local V2 = Vx * Vx + Vz * Vz

    local posProj = vec3.new()
    posProj.x = (ra * ra - rb * rb + U * U) / (2 * U)
    posProj.z = (ra * ra - rc * rc + V2 - 2 * Vx * posProj.x) / (2 * Vz)
    posProj.y = -math.sqrt(ra * ra - posProj.x * posProj.x - posProj.z * posProj.z)

    local pos = vec3.new()
    pos = pos + a
    pos.y = pos.y + posProj.y
    pos = pos + (ab * posProj.x)
    pos = pos + (abOrthogonal * posProj.z)

    return pos.x, pos.y, pos.z
end

return gpslib