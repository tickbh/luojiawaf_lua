require "lib"

local cjson = require("cjson")
local balancer = require "ngx.balancer"
local cache_data = require "cache_data"

local http_host = ngx.var.http_host
local cache_info = ngx.shared.cache_dict:get(GET_UPSTREAM_CACHE_KEY(http_host))
if not cache_info then
    local star_host = GET_MATCH_STAR_HOST(http_host)
    cache_info = ngx.shared.cache_dict:get(GET_UPSTREAM_CACHE_KEY(star_host))
end

if not cache_info then
    ngx.log(ngx.ERR, "not set upstream")
    return ngx.exit(500)
end

local upstream_json, from_cache = cache_data.get_cache_to_json(GET_UPSTREAM_CACHE_KEY(http_host), cache_info)
if not upstream_json then
    ngx.log(ngx.ERR, "convert json failed")
    return ngx.exit(500)
end

-- ngx.log(ngx.ERR, "check_json == ", from_cache, " ==",  cjson.encode(upstream_json))

local random_list = {}
local all_list = {}
for ip, data in pairs(upstream_json) do
    all_list[#all_list + 1] = ip
    local fail_times = ngx.shared.cache_dict:get(ip .. "fail") or 0
    if fail_times < (data["fail"] or 3) then
        random_list[#random_list + 1] = ip
    else
        local last_time = ngx.shared.cache_dict:get(ip .. "last_time") or 0
        if ngx.now() - last_time > (data["fail_timeout"] or 180) then
            ngx.shared.cache_dict:set(ip .. "fail", 0)
            random_list[#random_list + 1] = ip
        end
    end
end

local host = random_list
if #host == 0 then
    host = all_list
end

if #host == 0 then
    ngx.log(ngx.ERR, "failed get host ")
    return ngx.exit(500)
end


local port = ngx.var.server_port
local remote_ip = ngx.var.remote_addr
local key = remote_ip..port
local hash = ngx.crc32_long(key);
hash = (hash % 2) + 1

local backend = host[math.random(1, #host)]
local port = 80
local idx = string.find(backend, ":")
if idx then
    port = string.sub(backend, idx + 1, #backend)
    backend = string.sub(backend, 1, idx - 1)
end
local ok, err = balancer.set_current_peer(backend, port)
if not ok then
    ngx.log(ngx.ERR, "failed to set the current peer: ", err)
    return ngx.exit(500)
end
ok, err = balancer.set_timeouts(3, 60, 60)