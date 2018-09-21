package.path = package.path .. ";./?.lua"

local uuid = require("uuid")

local saveLua = {}

local getchr, serializeString, serializeNumber, serializeBoolean, serializeFunction, serializeTable, serializeValue

getchr = function(c)
    return "\\" .. c:byte()
end

serializeString = function(data)
    -- https://github.com/gvx/Ser/blob/master/ser.lua#L7-L9
    return ("%q"):format(data):gsub('\n', 'n'):gsub("[\128-\255]", getchr)
end

serializeNumber = function(data)
    return data .. ""
end

serializeBoolean = function(data)
    return data and "true" or "false"
end

-- Warning: upvalue are not serialized
serializeFunction = function(registry, data)
    if not registry[data] then
        local dataId = "ls_" .. uuid():gsub("-", "_")

        -- Register the function
        registry[data] = dataId

        -- Add the definition to the preamble
        registry.preamble = registry.preamble
            .. dataId .. "=(loadstring or load)(" .. serializeString(string.dump(data)) .. ");"
    end

    return registry[data]
end

serializeTable = function(registry, data)
    if not registry[data] then
        local dataId = "ls_" .. uuid():gsub("-", "_")

        -- Register the table
        registry[data] = dataId

        -- Add the definition to the preamble
        registry.preamble = registry.preamble .. dataId .. "={"

        for key, _ in pairs(data) do
            registry.preamble = registry.preamble
                .. "[" .. serializeValue(registry, key) .. "]"
                .. "="
                .. serializeValue(registry, rawget(data, key))
                .. ","
        end

        registry.preamble = registry.preamble .. "};"

        local metatable = getmetatable(data)

        if metatable then
            registry.preamble = registry.preamble
                .. "setmetatable(" .. dataId.. ", " .. serializeTable(registry, metatable) .. ");"
        end
    end

    return registry[data]
end

serializeValue = function(registry, value)
    local valueType = type(value)

    local serialized = ""

    if valueType == "string" then
        serialized = serialized .. serializeString(value)
    elseif valueType == "number" then
        serialized = serialized .. serializeNumber(value)
    elseif valueType == "boolean" then
        serialized = serialized .. serializeBoolean(value)
    elseif valueType == "table" then
        serialized = serialized .. serializeTable(registry, value)
    elseif valueType == "function" then
        serialized = serialized .. serializeFunction(registry, value)
    else
        error("Data of type " .. valueType .. " is unsupported")
    end

    return serialized
end

saveLua.serialize = function(data)
    local registry = {
        values = {},
        preamble = ""
    }

    local serialized = serializeValue(registry, data)

    return registry.preamble .. "return " .. serialized
end

return saveLua
