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
