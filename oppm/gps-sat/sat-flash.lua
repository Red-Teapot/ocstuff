local component = require('component')
local shell = require('shell')
local io = require('io')

local eeprom = component.eeprom

local arg, opt = shell.parse(...)

-- EEPROM data format for config storage
local format = '< i8i8i8 I4 I2 I2 f'

local x = opt.x
local y = opt.y or 255
local z = opt.z
local signalStrength = opt.signalStrength or 1000000
local energyThreshold = opt.energyThreshold or 1000
local listenPort = opt.listenPort or 42
local chargeDelay = opt.chargeDelay or 30

print('Writing config')
eeprom.setData(string.pack(format, x, y, z, signalStrength, energyThreshold, listenPort, chargeDelay))

print('Writing executable')
local executable = arg[1] or '../share/gps/satellite.lua'
local srcFile = io.open(executable, 'r')
local src = srcFile:read('a')
srcFile:close()

eeprom.set(src)

print('Setting label')
eeprom.setLabel('GPS sat at '..tostring(x)..' '..tostring(y)..' '..tostring(z))

print('Done')