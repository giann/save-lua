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
    if not registry.values[data] then
        local dataId = "ls_" .. uuid():gsub("-", "_")

        -- Register the function
        registry.values[data] = dataId
        registry.uncomplete[data] = dataId

        -- Add the definition to the output
        registry.output = registry.output
            .. "local " .. dataId .. "=(loadstring or load)(" .. serializeString(string.dump(data)) .. ");"

        -- Data is now fully defined
        registry.uncomplete[data] = nil
    end

    return registry.values[data]
end

serializeTable = function(registry, data)
    if not registry.values[data] then
        local dataId = "ls_" .. uuid():gsub("-", "_")

        -- Register the table
        registry.values[data] = dataId
        registry.uncomplete[data] = dataId

        -- Add the definition to the output
        local tableOutput = dataId .. "={};"

        local selfReferenceValues = {}
        local selfReferenceKeys = {}
        for key, _ in pairs(data) do
            local value = rawget(data, key)

            if value ~= data and key ~= data then
                local set = function()
                    return "rawset("
                    .. dataId
                    .. ","
                    .. serializeValue(registry, key)
                    .. ","
                    .. serializeValue(registry, value)
                    .. ");"
                end

                if registry.uncomplete[key] or registry.uncomplete[value] then
                    registry.post = set() .. registry.post
                else
                    tableOutput = tableOutput .. set()
                end
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
                tableOutput = tableOutput
                    .. "rawset("
                    .. dataId
                    .. ","
                    .. serializeValue(registry, selfReference)
                    .. ","
                    .. dataId .. ");"
            else
                -- t[t] = t
                tableOutput = tableOutput
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
            tableOutput = tableOutput
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
            tableOutput = tableOutput
                .. "setmetatable(" .. dataId.. ", " .. mtId .. ");"
        end

        registry.output = registry.output .. "local " .. tableOutput

        -- Data is now fully defined
        registry.uncomplete[data] = nil
    end

    return registry.values[data]
end

serializeValue = function(registry, value)
    if not registry.values[value] then
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
    end

    return registry.values[value]
end

return function(data)
    local registry = {
        -- Value that are not fully defined yet
        uncomplete = {},
        values = {},
        output = "",
        post = ""
    }

    if _G.__classes then
        for name, class in pairs(_G.__classes) do
            registry.values[class] = "_G.__classes[" .. serializeString(name) .. "]"
        end
    end

    local serialized = serializeValue(registry, data)

    return registry.output .. registry.post .. "return " .. serialized
end
