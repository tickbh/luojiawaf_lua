require 'lib'
require 'config'
local cache_data = require "cache_data"

local function upstream_response()
    ngx.update_time();
    local secs = ngx.now()
    local uri, client_ip, request_time, request_uri = ngx.var.uri, GET_CLIENT_IP(), ngx.var.request_time or 0, ngx.var.request_uri
    local upstream_response_time, upstream_addr = tonumber(ngx.var.upstream_response_time) or 0, ngx.var.upstream_addr or ""
    -- bytes_sent
    local status = ngx.status
    local raw_http_request = nil
    local is_need_record = false
    local is_random_record = math.random(10000) < GET_RANDOM_RECORD_VALUE()

    if RECORD_ERROR_STATUS[status] then
        raw_http_request = GET_RAW_HTTP_REQUEST_INFO()
    else
        local check = ngx.shared.ip_dict:get(client_ip)
        if check and string.find(check, "log") then
            is_need_record = true
            raw_http_request = GET_RAW_HTTP_REQUEST_INFO()
        elseif is_random_record then
            raw_http_request = GET_RAW_HTTP_REQUEST_INFO()
        end
    end

    local function record_func()
        -- upstream 次数与时间
        -- uri 次数与时间
        -- uri 异常次数与时间 > 10s则认为异常
        -- client_ip uri与次数
        -- client_ip uri时间耗时列表 list
        -- 用户的平均耗时, 若>总耗时的2倍, 则被重点监控
        -- 用户的访问时间, 若同一条url在未返回时又频繁触发重复访问, 则认为异常
        -- 分析正常用户与非正常用户的数据请求差

        local red = GET_REDIS_CLIENT()
        if is_need_record and raw_http_request then
            local add_pre = client_ip .. ":_:" .. ngx.now() .. "\r\n"
            local key = "client_url_lists:"..client_ip
            local len = red:lpush(key, add_pre .. raw_http_request)
            if len > 1000 then
                red:ltrim(key, 0, 999)
            end
            red:expire(key, 86400)
        elseif is_random_record and raw_http_request then
            local key = "client_random_url:"..GET_LAST_DAY_IDX()
            local add_pre = client_ip .. ":_:" .. ngx.now() .. "\r\n"
            local len = red:lpush(key, add_pre .. raw_http_request)
            if len > 10000 then
                red:ltrim(key, 0, 9999)
            end
            red:expire(key, 86400)
        end

        if upstream_addr == "" or upstream_response_time == 0 then
            return;
        end

        red:init_pipeline()
        local time_cost = CALC_TIMES_AND_COST_TIME(1, upstream_response_time)
        red:hincrbyfloat("upstream_all_cost", upstream_addr, time_cost)
        if upstream_response_time < 10 then
            red:hincrbyfloat("normal_all_cost", uri, time_cost)
        else
            red:hincrbyfloat("abnormally_all_cost", uri, time_cost)
        end

        local now_key = string.format("now_record_cost:%d", GET_LAST_HOUR_IDX())
        red:incrbyfloat(now_key, time_cost)
        red:expire(now_key, 36000)

        red:hincrby("client_ip_times:"..client_ip, uri, 1)
        red:expire("client_ip_times:"..client_ip, 600)

        local record_item = string.format("%s:_:%.3f:%.5f", request_uri, secs - request_time, request_time)
        red:lpush("client_ip_list:"..client_ip, record_item)
        red:expire("client_ip_list:"..client_ip, 600)

        red:hincrby("new_client_maps", client_ip, 1)

        if RECORD_ERROR_STATUS[status] and raw_http_request then
            local key = string.format("server_request_%d_%d", status, GET_LAST_DAY_IDX()) 
            red:zadd(key, ngx.now(), raw_http_request)
            red:expire(key, 86400 * 2)
        end
        red:commit_pipeline()
    end

    if (upstream_addr ~= "" and upstream_response_time ~= 0) or is_need_record  or is_random_record then
        local ok, err = ngx.timer.at(0, record_func)
    end

    if ngx.status >= 450 then
        local times = ngx.shared.cache_dict:incr(upstream_addr .. "fail", 1, 0)
        ngx.shared.cache_dict:set(upstream_addr .. "last_time", ngx.now())
    else
        ngx.shared.cache_dict:set(upstream_addr .. "fail", 0)
    end

    return true;
end

upstream_response()
