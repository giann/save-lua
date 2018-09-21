package.path = package.path .. ";../src/?.lua"

local serialize = require "savelua"

it("handles a basic table", function()
    local basicTable = {
        1, 2, 3,
        one = 1, two = 2, three = 3
    }

    local serialized = serialize(basicTable)
    local deserialized = (loadstring or load)(serialized)

    assert.is_not_nil(deserialized)

    local ok, data = pcall(deserialized)

    assert.is_true(ok)
    assert.are.same(basicTable, data)
end)

it("handles a basic table with metatable", function()
    local basicTable = {
        1, 2, 3,
        one = 1, two = 2, three = 3
    }

    local mt = {
        __call = function()
            return "hello from __call"
        end
    }

    setmetatable(basicTable, mt)

    local serialized = serialize(basicTable)
    local deserialized = (loadstring or load)(serialized)

    assert.is_not_nil(deserialized)

    local ok, data = pcall(deserialized)

    assert.is_true(ok)
    assert.are.same(basicTable, data)
    assert.are.equals("hello from __call", data())
end)

it("handles table self reference: t[t] = t, t[k] = t", function()
    local basicTable = {}

    basicTable.loop = basicTable
    basicTable[basicTable] = basicTable

    local serialized = serialize(basicTable)
    local deserialized = (loadstring or load)(serialized)

    assert.is_not_nil(deserialized)

    local ok, data = pcall(deserialized)

    assert.is_true(ok)
    assert.are.equals(data, data.loop)
    assert.are.equals(data, data[data])
end)

it("handles table self reference: t[t] = v", function()
    local basicTable = {}

    basicTable[basicTable] = "loop"

    local serialized = serialize(basicTable)
    local deserialized = (loadstring or load)(serialized)

    assert.is_not_nil(deserialized)

    local ok, data = pcall(deserialized)

    assert.is_true(ok)
    assert.are.equals("loop", data[data])
end)

it("handles deep self reference", function()
    local basicTable = {
        loop = {}
    }

    basicTable.loop.deep = basicTable

    local serialized = serialize(basicTable)
    local deserialized = (loadstring or load)(serialized)

    assert.is_not_nil(deserialized)

    local ok, data = pcall(deserialized)

    assert.is_true(ok)
    assert.are.equals(data, data.loop.deep)
end)

it("handles complex deep self reference 1", function()
    local basicTable = {
        loop = {}
    }

    basicTable.loop.deep = basicTable
    basicTable.loop.deep.gotcha = basicTable.loop

    local serialized = serialize(basicTable)
    local deserialized = (loadstring or load)(serialized)

    assert.is_not_nil(deserialized)

    local ok, data = pcall(deserialized)

    assert.is_true(ok)
    assert.are.equals(data, data.loop.deep, basicTable.loop.deep.gotcha)
end)

it("handles complex deep self reference 2", function()
    local basicTable = {
        loop = {},
        intermediate = { "intermediate" }
    }

    basicTable.loop.deep = basicTable
    basicTable.loop.gotcha = basicTable.intermediate

    local serialized = serialize(basicTable)
    local deserialized = (loadstring or load)(serialized)

    assert.is_not_nil(deserialized)

    local ok, data = pcall(deserialized)

    assert.is_true(ok)
    assert.are.equals(data, data.loop.deep)
    assert.are.equals(data.intermediate, data.loop.gotcha)
end)
