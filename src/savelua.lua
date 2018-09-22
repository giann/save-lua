local getchr, serializeString, serializeNumber, serializeBoolean,
    serializeFunction, serializeTable, serializeValue, nextId

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
        local dataId = nextId(registry)

        -- Register the function
        registry.values[data] = dataId
        registry.uncomplete[data] = dataId

        -- Add the definition to the output
        registry.output = registry.output
            .. "values[\"" .. dataId .. "\"]=(loadstring or load)(" .. serializeString(string.dump(data)) .. ")\n"

        -- Data is now fully defined
        registry.uncomplete[data] = nil
    end

    return registry.values[data]
end

serializeTable = function(registry, data)
    if not registry.values[data] then
        local dataId = nextId(registry)

        -- Register the table
        registry.values[data] = dataId
        registry.uncomplete[data] = dataId

        -- Add the definition to the output
        local tableOutput = "values[\"" .. dataId .. "\"]={}\n"

        local selfReferenceValues = {}
        local selfReferenceKeys = {}
        for key, _ in pairs(data) do
            local value = rawget(data, key)

            if value ~= data and key ~= data then
                local set = function()
                    return "rawset("
                    .. "values[\"" .. dataId .. "\"]"
                    .. ","
                    .. serializeValue(registry, key)
                    .. ","
                    .. serializeValue(registry, value)
                    .. ")\n"
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
                    .. "values[\"" .. dataId .. "\"]"
                    .. ","
                    .. serializeValue(registry, selfReference)
                    .. ","
                    .. "values[\"" .. dataId .. "\"]" .. ")\n"
            else
                -- t[t] = t
                tableOutput = tableOutput
                    .. "rawset("
                    .. "values[\"" .. dataId .. "\"]"
                    .. ","
                    .. "values[\"" .. dataId .. "\"]"
                    .. ","
                    .. "values[\"" .. dataId .. "\"]" .. ")\n"
            end
        end

        for i = 1, #selfReferenceKeys do
            local selfReference = selfReferenceKeys[i]

            -- t[t] = v
            tableOutput = tableOutput
                .. "rawset("
                .. "values[\"" .. dataId .. "\"]"
                .. ","
                .. "values[\"" .. dataId .. "\"]"
                .. ","
                .. serializeValue(registry, selfReference) .. ")\n"
        end

        local metatable = getmetatable(data)

        if metatable then
            local mtId = serializeTable(registry, metatable)
            tableOutput = tableOutput
                .. "setmetatable(" .. "values[\"" .. dataId .. "\"]".. ", " .. "values[\"" .. mtId .. "\"]" .. ")\n"
        end

        registry.output = registry.output .. tableOutput

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
            return "values[\"" .. serializeTable(registry, value) .. "\"]"
        elseif valueType == "function" then
            return "values[\"" .. serializeFunction(registry, value) .. "\"]"
        else
            error("Data of type " .. valueType .. " is unsupported")
        end
    end

    return "values[\"" .. registry.values[value] .. "\"]"
end

nextId = function(registry)
    registry.lastId = registry.lastId + 1

    return "ls_" .. registry.lastId
end

return function(data)
    local registry = {
        -- Value that are not fully defined yet
        uncomplete = {},
        values = {},
        output = "",
        post = "",
        lastId = 0
    }

    local preamble = "local values = {}\n"

    if _G.__classes then
        for name, class in pairs(_G.__classes) do
            local dataId = nextId(registry)
            registry.values[class] = dataId
            preamble = preamble .. "values[\"" .. dataId .. "\"]=_G.__classes[" .. serializeString(name) .. "]\n"
        end
    end

    local serialized = serializeValue(registry, data)

    return preamble
        .. registry.output
        .. registry.post
        .. "return " .. serialized
end
