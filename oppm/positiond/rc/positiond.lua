local positiond = require('positiond')

function start()
    positiond.init()
end

function stop()
    positiond.dispose()
end
