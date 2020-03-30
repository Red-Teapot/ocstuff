local serialization = require('serialization')

local utils = {}

function utils.sign(x)
    if x > 0 then
        return 1
    elseif x == 0 then
        return 0
    else
        return -1
    end
end

function utils.merge(dst, src)
    for key, value in pairs(src) do
        local t = type(value)

        if t == 'table' then
            if not dst[key] then
                dst[key] = {}
            end

            utils.merge(dst[key], value)
            setmetatable(dst[key], getmetatable(value))
        elseif t == 'nil' then
            -- Do nothing
        else
            dst[key] = value
        end
    end
end

function utils.pprint(var)
    print(serialization.serialize(var, true))
end

function utils.rerequire(lib)
    package.loaded[lib] = nil
    return require(lib)
end

return utils