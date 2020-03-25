local math = require('math')

local vec3meta = {}
local vec3 = {}

function vec3meta:__add(other)
    return vec3.new(self.x + other.x, self.y + other.y, self.z + other.z)
end

function vec3meta:__sub(other)
    return vec3.new(self.x - other.x, self.y - other.y, self.z - other.z)
end

function vec3meta:__unm()
    return vec3.new(-self.x, -self.y, -self.z)
end

function vec3meta:__eq(other)
    return self.x == other.x and self.y == other.y and self.z == other.z
end

function vec3meta:__index(idx)
    return vec3meta[idx]
end

function vec3meta:__tostring()
    return 'vec3(' .. self.x .. ', ' .. self.y .. ', ' .. self.z .. ')'
end

function vec3meta:lengthEuclid()
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function vec3meta:lengthManhattan()
    return math.abs(self.x) + math.abs(self.y) + math.abs(self.z)
end

function vec3meta:unpack()
    return self.x, self.y, self.z
end

function vec3.new(x, y, z)
    local vec = {}

    if x ~= nil then vec.x = x else vec.x = 0 end
    if y ~= nil then vec.y = y else vec.y = 0 end
    if z ~= nil then vec.z = z else vec.z = 0 end

    setmetatable(vec, vec3meta)

    return vec
end

function vec3.from(src)
    return vec3.new(src.x, src.y, src.z)
end

return vec3