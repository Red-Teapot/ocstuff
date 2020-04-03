local shell = require('shell')

function start(configPath)
    shell.execute('crop-farm', nil, configPath)
end