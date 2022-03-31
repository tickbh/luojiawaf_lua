--WAF Action
require 'config'
require 'lib'
local shell = require "resty.shell"


local function init_config()
    local cjson = require("cjson")
    local read_config = io.open('/etc/luojia.json',"r")
    if not read_config then
        read_config = assert(io.open(CONFIG_PUBLIC..'/luojia.json',"r"))
    end
	local raw_config_info = read_config:read('*all')
    read_config:close()
	local config_info = cjson.decode(raw_config_info)
	if config_info == nil then
		ngx.log(ngx.ERR,"init fail,can not decode config file")
    else
        GLOBAL_CONFIG_INFO = config_info
	end
end

init_config()

local function check_upstream_addr(red)
    local cjson = require("cjson")
    local hosts = {}
    local datas = red:hgetall("all_upstream_infos") or {}
    for i = 1, #datas / 2 do
        local k, v = datas[i * 2 - 1], datas[i * 2]
        local infos = cjson.decode(v)
        if infos then
            local host, ip, port  = infos["host"], infos["ip"], infos["port"]
            hosts[host] = hosts[host] or {}
            hosts[host][ip..":"..port] = infos
        end
    end

    for host, data in pairs(hosts) do
        ngx.shared.cache_dict:set(GET_UPSTREAM_CACHE_KEY(host), cjson.encode(data))
        ngx.shared.cache_dict:expire(GET_UPSTREAM_CACHE_KEY(host), 3600)
    end
end

local function sync_all_records_ips(red)
    local datas = red:hgetall("all_record_ips")
    if not datas or #datas == 0 then
        return
    end
    for i = 1, #datas / 2 do
        ngx.shared.ip_dict:set(datas[i * 2 - 1], datas[i * 2])
        ngx.shared.ip_dict:expire(datas[i * 2 - 1], 120)
    end
end

local function sync_all_white_urls(red)
    local datas = red:hgetall("all_white_urls")
    if not datas or #datas == 0 then
        return
    end
    for i = 1, #datas / 2 do
        ngx.shared.cache_dict:set("WU:" .. datas[i * 2 - 1], datas[i * 2])
        ngx.shared.cache_dict:expire("WU:" .. datas[i * 2 - 1], 120)
    end
end

local function sync_all_ip_changes(red)
    local datas = red:hgetall("all_ip_changes")
    if not datas or #datas == 0 then
        return
    end
    red:del("all_ip_changes")

    for i = 1, #datas / 2 do
        local k, v = datas[i * 2 - 1], datas[i * 2]
        if string.find(v, "del") then
            ngx.shared.ip_dict:delete("f:"..k)
            REMOVE_FORBIDDEN(k)
        elseif string.find(v, "add") then
            ngx.shared.ip_dict:set("f:"..k, "deny")
            local deny_time = tonumber(string.match(v,'%d+')) or 600
            ngx.shared.ip_dict:expire("f:"..k, deny_time)
        elseif string.find(v, "captcha") then
            local split = STRING_SPLIT(v, "|")
            local  timeout, key = split[2], split[3]

            ngx.log(ngx.ERR, "add ip ", k, " key = ", key, " v ==", v, " timeout ==", timeout)
            ngx.shared.ip_dict:set("f:"..k, "captcha")
            ngx.shared.ip_dict:set("f:"..k..":key", key)

            local deny_time = tonumber(timeout) or 600
            ngx.shared.ip_dict:expire("f:"..k, deny_time)
            ngx.shared.ip_dict:expire("f:"..k..":key", deny_time)
        end
    end
end

local function sync_cache_to_redis(red)
    local times = ngx.shared.cache_dict:get(CC_ATTACK_CACHE_TIMES_KEY) or 0
    if times > 0 then
        red:incrby("cc_attack_cache_times:" .. GET_LAST_DAY_IDX(), times)
        ngx.shared.cache_dict:set(CC_ATTACK_CACHE_TIMES_KEY, 0)
    end
end

local function read_config_from_redis(red)
    local datas = red:hgetall("all_config_infos") or {}
    for i = 1, #datas / 2 do
        local k, v = datas[i * 2 - 1], datas[i * 2]
        ngx.shared.cache_dict:set("config_"..k, v)
        ngx.shared.cache_dict:expire("config_"..k, 300)
    end
end


local function read_ssl_from_redis(red)
    local cjson = require("cjson")
    local datas = red:hgetall("all_ssl_infos") or {}
    for i = 1, #datas / 2 do
        local k, v = datas[i * 2 - 1], datas[i * 2]
        local infos = cjson.decode(v)
        if infos then
            local host, pem, pem_key = infos["host"], infos["pem"], infos["pem_key"]
            if host then
                ngx.shared.cache_dict:set("ssl:pem:"..host, pem, 300) -- like ssl:pem:example.com or ssl:key:example.com
                ngx.shared.cache_dict:set("ssl:key:"..host, pem_key, 300) -- like ssl:pem:example.com or ssl:key:example.com
            end
        end
    end
end

local function statistics_system_info(red)
    local command = GET_STATIS_COMMAND()
    local shell_cmd = {}
    shell_cmd[1] = command .. " "
    shell_cmd[2] = "3"

    local ok, stdout, stderr, reason, status =  shell.run(table.concat(shell_cmd), nil, 5000, 4069)
    
    if not ok then
        ngx.log(ngx.ERR,stdout, stderr, reason, status)
        return
    end

    local ret_table = STRING_SPLIT(stdout, " ")
    local now = ngx.now()
    now = now - now % 15

    local function _push_to_list(key, value)
        local len = red:rpush(key, value)
        if len >= 9999 then
            red:ltrim(key, len - 9999, -1)
        end
    end

    _push_to_list("all_cpu_info", now .. "/" .. (ret_table[2] or "0"))
    _push_to_list("all_mem_info", now .. "/" .. (ret_table[3] or "") .. "/" .. (ret_table[4] or ""))
    _push_to_list("all_network_info", now .. "/" .. (ret_table[5] or "") .. "/" .. (ret_table[6] or "") .. "/" .. (ret_table[7] or ""))
end

local function do_timer()
    local red = GET_REDIS_CLIENT()
    ngx.update_time()

    local last_timer_update = ngx.now()
    local record = ngx.shared.cache_dict:get("last_timer_update") or 0
    if last_timer_update - record < 10 then
        return
    end
    ngx.shared.cache_dict:set("last_timer_update", last_timer_update)

    ngx.log(ngx.ERR, "reload data info in do_timer:", ngx.now(), " worker id:", ngx.worker.id())
    check_upstream_addr(red)
    read_config_from_redis(red)
    sync_cache_to_redis(red)
    sync_all_records_ips(red)
    sync_all_white_urls(red)
    sync_all_ip_changes(red)
    read_ssl_from_redis(red)
    statistics_system_info(red)
    ngx.log(ngx.ERR, "redis ping result ", red:ping(), " worker id:", ngx.worker.id())
    
end

ngx.timer.every(15, do_timer)
ngx.timer.at(1, do_timer)