local shell = require('shell')

function start(configPath)
    if not configPath then configPath = '/home/crop-farm-cfg' end

    shell.execute('crop-farm', nil, configPath)
end