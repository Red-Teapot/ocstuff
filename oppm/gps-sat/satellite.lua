local function get(name)
    return component.proxy(component.list(name)())
end

local eeprom = get('eeprom')
local robot = get('robot')
local modem = get('modem')

-- Read config from EEPROM data section
local format = '< i8i8i8 I4 I2 I2 f'
local x, y, z, signalStrength, energyThreshold, listenPort, chargeDelay = string.unpack(format, eeprom.getData())

modem.setStrength(signalStrength)
modem.setWakeMessage('gps-wakeup')
modem.broadcast(listenPort, 'gps-wakeup')

while true do
    if computer.energy() > energyThreshold then
        -- Move up to the world height limit
        if not robot.move(1) then
            break
        end
    else
        -- Wait some time to hopefully charge
        computer.pullSignal(chargeDelay)
    end
end

modem.open(listenPort)

local function respond(remoteAddress, responsePort)
    -- Try to handle as much errors as possible to avoid crashing
    if computer.energy() < energyThreshold then return end
    if type(responsePort) ~= 'number' then return end
    responsePort = math.floor(responsePort)
    if responsePort < 1 or responsePort > 65535 then return end

    modem.send(remoteAddress, responsePort, x, y, z)
end

while true do
    local evt, _, remoteAddress, _, _, responsePort = computer.pullSignal()

    if evt == 'modem_message' then
        respond(remoteAddress, responsePort)
    end
end
