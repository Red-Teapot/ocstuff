local gps = require('gps')
local positiond = require('positiond')
local vec3 = require('vec3')

function start(cfg)
    if not cfg then cfg = {} end
    local x, y, z = gps.locate(cfg.responsePort, cfg.timeout, cfg.maxTries, cfg.satellitePort)

    if x ~= nil and y ~= nil and z ~= nil then
        positiond.setPosition(vec3.new(x, y, z))
    end
end