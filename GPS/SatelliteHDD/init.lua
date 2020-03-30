local cfg = {
    x = 18,
    y = 255,
    z = 18,
    signalStrength = 1000000,
    energyThreshold = 1000,
    listenPort = 42,
    chargeDelay = 30,
}

local robot = component.proxy(component.list('robot')())
local modem = component.proxy(component.list('modem')())

modem.setStrength(cfg.signalStrength)
modem.setWakeMessage('gps-wakeup')
modem.broadcast(cfg.listenPort, 'gps-wakeup')

while true do
    if computer.energy() > cfg.energyThreshold then
        -- Move up to the world height limit
        if not robot.move(1) then
            break
        end
    else
        -- Wait some time to hopefully charge
        computer.pullSignal(cfg.chargeDelay)
    end
end

modem.open(cfg.listenPort)

local function respond(remoteAddress, responsePort)
    -- Try to handle as much errors as possible to avoid crashing
    if computer.energy() < cfg.energyThreshold then return end
    if type(responsePort) ~= 'number' then return end
    responsePort = math.floor(responsePort)
    if responsePort < 1 or responsePort > 65535 then return end

    modem.send(remoteAddress, responsePort, cfg.x, cfg.y, cfg.z)
end

while true do
    local evt, _, remoteAddress, _, _, responsePort = computer.pullSignal()

    if evt == 'modem_message' then
        respond(remoteAddress, responsePort)
    end
end
