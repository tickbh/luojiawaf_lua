-- cache_data.lua
local _M = {}

local cookie = 1
local cache_table = {}
function _M.get_new_cookie()
    cookie = cookie + 1;
    if (cookie > 1000000) then
        cookie = 1;
    end
    return cookie;
end

function _M.get_cache_table()
    return cache_table;
end

function _M.get_cache_data(key)
    return cache_table[key];
end

function _M.set_cache_data(key, value)
    cache_table[key] = value;
end

function _M.get_cache_to_json(key, origin)
    if not origin then
        return nil, false
    end
    local cache_value = cache_table[key]
    local cache_json = cache_table[key .. "_json"]

    if cache_json and origin == cache_value then
        return cache_json, true
    end

    local cjson = require("cjson")
    cache_json = cjson.decode(origin)
    cache_table[key] = origin
    cache_table[key .. "_json"] = cache_json
    return cache_json, false
end

return _M
