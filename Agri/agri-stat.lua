local metatable = {}

function metatable:__lt(other)
    if other.growth > self.growth and other.gain > self.gain and other.strength > self.strength then
        return true
    end

    local integral = other.growth - self.growth
    integral = integral + other.gain - self.gain
    integral = integral + other.strength - self.strength

    return integral > 0
end

local agri_stat = {}

function agri_stat.new(growth, gain, strength)
    if not growth then growth = 0 end
    if not gain then gain = 0 end
    if not strength then strength = 0 end

    local result = {
        growth = growth,
        gain = gain,
        strength = strength,
    }

    setmetatable(result, metatable)

    return result
end

function agri_stat.from(src)
    local growth = src.growth
    local gain = src.gain
    local strength = src.strength

    if not growth then growth = 0 end
    if not gain then gain = 0 end
    if not strength then strength = 0 end

    return agri_stat.new(growth, gain, strength)
end

return agri_stat