package.path = package.path .. ";./?.lua"

local uuid = require("uuid")

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

        -- Add the definition to the output
        registry.output = registry.output
            .. "local " .. dataId .. "=(loadstring or load)(" .. serializeString(string.dump(data)) .. ");"
    end

    return registry[data]
end

serializeTable = function(registry, data)
    if not registry[data] then
        local dataId = "ls_" .. uuid():gsub("-", "_")

        -- Register the table
        registry[data] = dataId

        -- Add the definition to the output
        local tablePreamble = dataId .. "={};"

        local selfReferenceValues = {}
        local selfReferenceKeys = {}
        for key, _ in pairs(data) do
            local value = rawget(data, key)

            if value ~= data and key ~= data then
                tablePreamble = tablePreamble
                    .. "rawset("
                    .. dataId
                    .. ","
                    .. serializeValue(registry, key)
                    .. ","
                    .. serializeValue(registry, value)
                    .. ");"
            elseif value == data then
                    table.insert(selfReferenceValues, key)
            elseif key == data then
                table.insert(selfReferenceKeys, value)
            end
        end

        -- Handle self references
        for i = 1, #selfReferenceValues do
            local selfReference = selfReferenceValues[i]

            if selfReference ~= data then
                -- t[k] = t
                tablePreamble = tablePreamble
                    .. "rawset("
                    .. dataId
                    .. ","
                    .. serializeValue(registry, selfReference)
                    .. ","
                    .. dataId .. ");"
            else
                -- t[t] = t
                tablePreamble = tablePreamble
                    .. "rawset("
                    .. dataId
                    .. ","
                    .. dataId
                    .. ","
                    .. dataId .. ");"
            end
        end

        for i = 1, #selfReferenceKeys do
            local selfReference = selfReferenceKeys[i]

            -- t[t] = v
            tablePreamble = tablePreamble
                .. "rawset("
                .. dataId
                .. ","
                .. dataId
                .. ","
                .. serializeValue(registry, selfReference) .. ");"
        end

        local metatable = getmetatable(data)

        if metatable then
            local mtId = serializeTable(registry, metatable)
            tablePreamble = tablePreamble
                .. "setmetatable(" .. dataId.. ", " .. mtId .. ");"
        end

        registry.output = registry.output .. "local " .. tablePreamble
    end

    return registry[data]
end

serializeValue = function(registry, value)
    local valueType = type(value)

    if valueType == "string" then
        return serializeString(value)
    elseif valueType == "number" then
        return serializeNumber(value)
    elseif valueType == "boolean" then
        return serializeBoolean(value)
    elseif valueType == "table" then
        return serializeTable(registry, value)
    elseif valueType == "function" then
        return serializeFunction(registry, value)
    else
        error("Data of type " .. valueType .. " is unsupported")
    end

    return nil
end

return function(data)
    local registry = {
        values = {},
        output = ""
    }

    local serialized = serializeValue(registry, data)

    return registry.output .. "return " .. serialized
end
