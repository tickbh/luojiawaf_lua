require 'config'
local shell = require "resty.shell"
local limit_req = require "resty.limit.req"
local cache_data = require "cache_data"

CLIENT_DEFAULT = "unknown"

RECORD_ERROR_STATUS = {}
RECORD_ERROR_STATUS[404] = true
RECORD_ERROR_STATUS[500] = true

RANDOM_RECORD_VALUE = 100

local may_real_ip_headers = {"X-Forwarded-For", "x-forwarded-for", "luojiawaf_real_ip"}

--Get the client IP
function GET_CLIENT_IP()
    local client_ip = nil
    local cjson = require("cjson")
    for _, val in ipairs(may_real_ip_headers) do
        client_ip = ngx.req.get_headers()[val]
        if client_ip then
            return client_ip
        end
    end
    if client_ip == nil then
        client_ip  = ngx.var.remote_addr
    end
    if client_ip == nil then
        client_ip  = CLIENT_DEFAULT
    end
    return client_ip
end

--Get the client user agent
function GET_USER_AGENT()
    USER_AGENT = ngx.var.http_user_agent
    if USER_AGENT == nil then
       USER_AGENT = "unknown"
    end
    return USER_AGENT
end

function OBJECT_TO_STRING(obj)
    local cjson = require("cjson")
    return cjson.encode(obj)
end

function INCR_KEY_VERSION(key)
    local red = GET_REDIS_CLIENT()
    local version_key = string.format("version_%s", key)
    red:incr(version_key, 1)
end

--Get WAF rule
function GET_RULE(rulefilename)

    local rules = cache_data.get_cache_data(rulefilename)
    if rules then
        return rules
    end

    local io = require 'io'
    local file = io.open(CONFIG_RULE_DIR..'/'..rulefilename,"r")
    if file == nil then
        ngx.log(ngx.ERR, CONFIG_RULE_DIR..'/'..rulefilename, " not exist ")
        cache_data.set_cache_data(rulefilename, {})
        return
    end
    local ret_table = {}
    for line in file:lines() do
        line = line:gsub("^%s*(.-)%s*$", "%1")
        if line ~= "" then
            table.insert(ret_table, line)
        end
    end
    file:close()
    cache_data.set_cache_data(rulefilename, ret_table)
    return(ret_table)
end

--WAF log record for json,(use logstash codec => json)
function LOG_RECORD(method,url,data,ruletag)
    local cjson = require("cjson")
    local CLIENT_IP = GET_CLIENT_IP()
    local USER_AGENT = GET_USER_AGENT()
    local SERVER_NAME = ngx.var.server_name
    local LOCAL_TIME = ngx.localtime()
    local log_json_obj = {
                 client_ip = CLIENT_IP,
                 local_time = LOCAL_TIME,
                 server_name = SERVER_NAME,
                 user_agent = USER_AGENT,
                 attack_method = method,
                 req_url = url,
                 req_data = data,
                 rule_tag = ruletag,
              }
    local LOG_LINE = cjson.encode(log_json_obj)
    ngx.log(ngx.ERR, "waf info: ", LOG_LINE)
end

function WAF_CAPTCHA_OUT()
    local client_ip = GET_CLIENT_IP()
    local key = ngx.var.uri
    local captcha_key = "f:"..client_ip..":key"
    local cap_key = ngx.shared.ip_dict:get(captcha_key) or ""
    if key == "/luojiawaf/capimg" then
        local red = GET_REDIS_CLIENT()
        local png = red:get("image_" .. cap_key)
        ngx.header.content_type = "image/png"
        ngx.say(png)
        ngx.exit(ngx.HTTP_OK)
        return
    elseif key == "/luojiawaf/capt/refresh" then
        ngx.header.content_type = "text/plain"
        local timer_key = "f:"..client_ip .. ":timer"
        local current = ngx.shared.ip_dict:incr(timer_key, 1, 0, 600)
        if current > 5 then
            ADD_FORBIDDEN_TIME(GET_CLIENT_IP())
            ngx.say("error")
            ngx.exit(ngx.HTTP_OK)
        end
        local red = GET_REDIS_CLIENT()
        local cjson = require("cjson")
        local info = cjson.encode({
            action = "captcha_refresh",
            ip = client_ip,
        })
        red:hset("all_import_msg", info, ngx.now())

        ngx.say("ok")
        ngx.exit(ngx.HTTP_OK)
    elseif key == "/luojiawaf/captcha" then
        local args = {}
        if ngx.req.get_method() == "POST" then
            ngx.req.read_body()

            if ngx.req.get_headers()["Content-Type"] == 'application/json' then
                local data = ngx.req.get_body_data()
                if not data then
                    return true
                end
                local cjson = require("cjson")
                args = cjson.decode(data)
            else
                args = ngx.req.get_post_args()
            end
        else
            args = ngx.req.get_uri_args()
        end

        local red = GET_REDIS_CLIENT()
        local check_captcha = red:get("result_" .. cap_key)
        local captcha = args["captcha"] or ""
        ngx.header.content_type = "text/plain"
        if check_captcha ~= string.upper(captcha) then
            ADD_FORBIDDEN_TIME(GET_CLIENT_IP())
            ngx.say("error")
            ngx.exit(ngx.HTTP_OK)
        end

        ngx.shared.ip_dict:set("f:"..client_ip, "nocheck")
        ngx.shared.ip_dict:expire("f:"..client_ip, 600)

        local cjson = require("cjson")
        local info = cjson.encode({
            action = "captcha_ok",
            ip = client_ip,
        })
        red:hset("all_import_msg", info, ngx.now())

        ngx.say("ok")
        ngx.exit(ngx.HTTP_OK)
    end
    ngx.header.content_type = "text/html"
    local info = string.gsub(CONFIG_CAPTCHA_HTML, "local_client_ip", GET_CLIENT_IP())
    ngx.say(info)
    ngx.exit(ngx.HTTP_OK)
end


function WAF_OUTPUT()
    ngx.shared.cache_dict:incr(CC_ATTACK_CACHE_TIMES_KEY, 1, 0)
    if CONFIG_WAF_OUTPUT == "redirect" then
        ngx.redirect(CONFIG_WAF_REDIRECT_URL, 301)
    else
        ngx.header.content_type = "text/html"
        ngx.status = ngx.HTTP_OK
        local info = string.gsub(CONFIG_OUTPUT_HTML, "local_client_ip", GET_CLIENT_IP())
        ngx.say(info)
        ngx.exit(ngx.status)
    end
end

function WAF_TOO_FASTER()
    ngx.shared.cache_dict:incr(CC_ATTACK_CACHE_TIMES_KEY, 1, 0)
    if CONFIG_WAF_OUTPUT == "redirect" then
        ngx.redirect(CONFIG_WAF_REDIRECT_URL, 301)
    else
        ngx.header.content_type = "text/html"
        ngx.status = ngx.HTTP_OK
        ngx.say(CONFIG_TOOFASTER_HTML)
        ngx.exit(ngx.status)
    end
end


function TIP_SERVER_INFO(info)
    ngx.header.content_type = "text/html"
    ngx.status = ngx.HTTP_OK
    ngx.say(info)
    ngx.exit(ngx.status)
end
--2015-01-01
function GET_CYCLICAL_IDX(cyclical, now)
    if not now then
        now = ngx.now()
    end
    return math.floor((tonumber(now) - 1420041600) / cyclical)
end

function GET_LAST_HOUR_IDX(now)
    local idx = GET_CYCLICAL_IDX(3600, now)
    return idx
end

function GET_LAST_DAY_IDX(now)
    local idx = GET_CYCLICAL_IDX(86400, now)
    return idx
end

-- 对得数/1000向下取整得出次数, 对得数取1000以下的位数*1000得出总时长
function CALC_TIMES_AND_COST_TIME(times, cost_time)
    cost_time = math.min(100, cost_time)
    cost_time = cost_time / 1000
    times = times * 1000
    return cost_time + times
end

function GET_RAW_HTTP_REQUEST_INFO(read_body)
    local raw_header = ngx.req.raw_header()

    if read_body then
        ngx.req.read_body()
    end
    local post_data = ngx.req.get_body_data()
    if post_data then
        return raw_header .. post_data
    else
        return raw_header
    end
end

--args
local rulematch = ngx.re.find
local unescape = ngx.unescape_uri

-- 数据缓存时间, 一分钟
CACHE_STEP = 60

WHITE_IP_STR = "white_ip_str"
WHITE_IP_CACHE_TIME = "white_ip_cache"
CC_ATTACK_CACHE_TIMES_KEY = "cc_attack_cache_times_key"
SYNC_IP_LAST_TIME_KEY = "sync_ip_last_time"


function GET_UPSTREAM_CACHE_KEY(host)
    host = host or "*"
    return "upstream:" .. host
end

--allow white ip
function WHITE_IP_CHECK()
    if GET_CONFIG_WHITE_IP() == "on" then
        local value = ngx.shared.ip_dict:get("f:"..GET_CLIENT_IP())
        if value and string.find(value, "allow") then
            return true
        end
    end
end

--allow white url
function WHITE_URL_CHECK()
    if GET_CONFIG_WHITE_URI() == "on" then
        local uri = ngx.var.request_uri
        local uri_table = STRING_SPLIT(uri, "/")
        local is_first = true
        while #uri_table >= 1 do
            local new_uri = "/" .. table.concat(uri_table, "/")
            local value = ngx.shared.cache_dict:get("WU:" .. new_uri)
            if value then
                if is_first and string.find(value, "all") then
                    ngx.ctx.is_white = true
                    return true
                end
                if string.find(value, "start") then
                    ngx.ctx.is_white = true
                    return true
                end
            end
            table.remove(uri_table, #uri_table)
            is_first = false
        end
    end
end

local function check_args_vaild(req_args, rules_args)
    if not rules_args or not req_args then
        return
    end
    for key, val in pairs(req_args) do
        local args_data = val
        if type(val) == 'table' then
            local cjson = require("cjson")
            args_data = cjson.encode(val)
        end
        args_data = unescape(args_data)
        if args_data and type(args_data) ~= "boolean" then
            for _,rule in pairs(rules_args) do
                if rulematch(args_data,rule,"jo") then
                    LOG_RECORD('Deny_URL_Args',ngx.var.request_uri,"-",rule)
                    RECORD_ACCTACK_REQUEST()
                    ADD_FORBIDDEN_TIME(GET_CLIENT_IP())
                    WAF_OUTPUT()
                    return true, rule
                end
            end
        end
        
    end
end

--deny url args
function URL_ARGS_ATTACK_CHECK()
    if GET_CONFIG_URL_ARGS_ATTACK() == "on" then
        local rules_args = GET_RULE('args.rule')
        local req_args = ngx.req.get_uri_args()
        local vaild, pattern = check_args_vaild(req_args, rules_args)
        if vaild then
            return true
        end
    end
    return false
end

--deny post
function POST_ATTACK_CHECK()
    if GET_CONFIG_POST_ATTACK() == "on" and ngx.req.get_method() == "POST" then
        local rules_args = GET_RULE('post.rule')
        ngx.req.read_body()
        local post_args = {}
        if ngx.req.get_headers()["Content-Type"] == 'application/json' then
            local data = ngx.req.get_body_data()
            if not data then
                return true
            end
            local cjson = require("cjson")
            post_args = cjson.decode(data)
        else
            post_args = ngx.req.get_post_args()
        end
        local vaild, pattern = check_args_vaild(post_args, rules_args)
        if vaild then
            return true
        end
    end
    return false
end

local function get_small_number(number)
    local _, small = math.modf(number)
    return small
end

function FORBIDDEN_IP_CHECK()
    if GET_CONFIG_FORBIDDEN_IP() == "on" then
        local cleint_ip = GET_CLIENT_IP()
        local value = ngx.shared.ip_dict:get("f:"..cleint_ip)

        if value and string.find(value, "deny") then
            LOG_RECORD('Deny_URL_Args',ngx.var.request_uri,"-","forbidden")
            ADD_FORBIDDEN_TIME(cleint_ip)
            WAF_OUTPUT()
            return true
        elseif value and string.find(value, "captcha") then
            LOG_RECORD('Deny_URL_Args',ngx.var.request_uri,"-","captcha")
            WAF_CAPTCHA_OUT()
            return true
        end
    end
end

function INCR_IN_STREAM(time, host, bytes)
    if string.match(host,'%d+.%d+.%d+.%d+') == host then
        host = "ip_host"
    end
    local idx = GET_CYCLICAL_IDX(60, time)
    local limit = ngx.shared.limit
    local host_request = "in:" .. host .. idx
    local now, err = limit:incr(host_request, bytes, 0, 60)
    local in_limit = GET_IN_LIMIT(host)

    if in_limit > 0 and now > in_limit then
        for step=1,10 do
            local new_idx = step + idx
            local host_request = "in:" .. host .. new_idx
            local value = limit:get(host_request) or 0
            if value < in_limit then
                limit:incr(host_request, bytes, 0, 60)
                return step - get_small_number(time)
            end
        end
        -- 超过10秒统一延时20秒, 不立即返回, 防止客户端无限请求刷流量
        return 11
    end
    return 0
end

local function _incr_out_stream(time, host, bytes)
    if string.match(host,'%d+.%d+.%d+.%d+') == host then
        host = "ip_host" 
    end
    local idx = GET_CYCLICAL_IDX(60, time)
    local limit = ngx.shared.limit
    local out_limit = GET_OUT_LIMIT(host)
    if out_limit > 0 then
        for step=0,10 do
            local new_idx = step + idx
            local host_request = "out:" .. host .. new_idx
            local value = limit:incr(host_request, bytes, 0, 60 * step)
            if value == bytes or value < out_limit then
                break
            end 
        end
    end
end

function INCR_OUT_STREAM(time, host, bytes)
    if GET_CONFIG_STREAM_LIMIT() == "on" then
        _incr_out_stream(time, host, bytes)
        _incr_out_stream(time, "*", bytes)
    end
end

function CHECK_OUT_DELAY(time, host)
    local idx = GET_CYCLICAL_IDX(60, time)
    local limit = ngx.shared.limit
    local out_limit = GET_OUT_LIMIT(host)
    if out_limit > 0 then
        for step=0,10 do
            local new_idx = step + idx
            local host_request = "out:" .. host .. new_idx
            local value = limit:get(host_request) or 0
            if value < out_limit then
                return math.max(0, step - get_small_number(time))
            end
        end

        return 10
    end
    return 0
end

function CHECK_STREAM_LIMIT()
    if GET_CONFIG_STREAM_LIMIT() == "on" then
        if not IS_IN_LIMIT_TIME() then
            return
        end
        local host = ngx.var.http_host
        if string.match(host,'%d+.%d+.%d+.%d+') == host then
            host = "ip_host" 
        end

        local time = ngx.now()
        local delay = INCR_IN_STREAM(time, host, ngx.var.request_length)
        if delay > 0 then
            ngx.log(ngx.ERR, host, " in over limit delay request ", delay)
            ngx.sleep(delay)
            return
        end

        local delay = INCR_IN_STREAM(time, "*", ngx.var.request_length)
        if delay > 0 then
            ngx.log(ngx.ERR, "*", " in over limit delay request ", delay)
            ngx.sleep(delay)
            return
        end

        local delay = CHECK_OUT_DELAY(time, host)
        if delay > 0 then
            ngx.log(ngx.ERR, host, " out over limit delay request ", delay)
            ngx.sleep(delay)
            return
        end

        local delay = CHECK_OUT_DELAY(time, "*")
        if delay > 0 then
            ngx.log(ngx.ERR, "*", " out over limit delay request ", delay)
            ngx.sleep(delay)
            return
        end
    end
end

function ADD_REOCRD_VISIT()
    local red = GET_REDIS_CLIENT()
    local raw_http_request = GET_RAW_HTTP_REQUEST_INFO(true)
    local client_ip = GET_CLIENT_IP()
    local add_pre = client_ip .. ":_:" .. ngx.now() .. "\r\n"
    local key = "client_url_lists:"..client_ip
    local len = red:lpush(key, add_pre .. raw_http_request)
    if len > 1000 then
        red:ltrim(key, 0, 999)
    end
    red:expire(key, 86400)
end

function ADD_FORBIDDEN_TIME(client_ip)
    local cc_fobidden = "cc_fobidden:"..client_ip
    local limit = ngx.shared.limit
    local now, _err = limit:incr(cc_fobidden, 1, 0, 60)
    if now > GET_FORBIDDEN_BY_FIREWALL_TIMES() then
        local red = GET_REDIS_CLIENT()
        red:hset("all_ip_changes", client_ip, string.format("add|%d", os.time() + 600))
        INCR_KEY_VERSION("all_ip_changes")
    end

    if GET_CONFIG_FORBIDDEN_RECORD() == "on" then
        ADD_REOCRD_VISIT()
    end
end

function REMOVE_FORBIDDEN(client_ip)
    local cc_fobidden = "cc_fobidden:"..client_ip
    local red = GET_REDIS_CLIENT()
    red:del(cc_fobidden)
end

function LIMIT_IP_CHECK()
    if GET_CONFIG_LIMIT_IP() == "on" then
        if not IS_IN_LIMIT_TIME() then
            return
        end
        local key = GET_CLIENT_IP()
        local ok = GET_CONFIG_LIMIT_ONE_IP(key)
        if not ok then
            ok = GET_CONFIG_LIMIT_ALL_IP()
        end
        if ok then
            local bucket_rate, bucket_burst = string.match(ok,'(.*)/(.*)')
            bucket_rate, bucket_burst = tonumber(bucket_rate) or 200, tonumber(bucket_burst) or 100

            local lim, err = limit_req.new("limit", bucket_rate, bucket_burst)
            if not lim then
                ngx.log(ngx.ERR, "init limit_req failed reason:" .. err)
                return ngx.exit(500)
            end

            local delay, err = lim:incoming(key, true)
            if not delay then
                if err == "rejected" then
                    return WAF_TOO_FASTER()
                end
            end

            if delay > 0.001 then
                ngx.log(ngx.ERR, "delay request " .. delay)
                ngx.sleep(delay)
            end
        end
    end
end

function LIMIT_URI_CHECK()
    if GET_CONFIG_LIMIT_URL() == "on" then
        if not IS_IN_LIMIT_TIME() then
            return
        end
        local key = ngx.var.uri
        local ok = GET_CONFIG_LIMIT_ONE_URI(key)
        if not ok then
            ok = GET_CONFIG_LIMIT_ALL_URI()
        end
        if ok then
            local bucket_rate, bucket_burst = string.match(ok,'(.*)/(.*)')
            bucket_rate, bucket_burst = tonumber(bucket_rate) or 200, tonumber(bucket_burst) or 100

            local lim, err = limit_req.new("limit", bucket_rate, bucket_burst)
            if not lim then
                ngx.log(ngx.ERR, "init limit_req failed reason:" .. err)
                return ngx.exit(500)
            end

            local delay, err = lim:incoming(key, true)
            if not delay then
                if err == "rejected" then
                    return WAF_TOO_FASTER()
                end
            end

            if delay > 0.001 then
                ngx.log(ngx.ERR, "delay request " .. delay)
                ngx.sleep(delay)
            end
        end
    end
end

local function _check_in_limit()
    local weekday, time = GET_CONFIG_LIMIT_WEEKDAY(), GET_CONFIG_LIMIT_TIME()
    if not weekday and not time then
        return true
    end

    if weekday then
        local current_week_day = os.date("%w")
        if not string.find(weekday, current_week_day.."") then
            return false
        end
    end

    if time then
        local current_date = os.date('*t')
        local hour, min = current_date['hour'], current_date['min']
        local step = hour * 60 + min
        for sh, sm, eh, em in string.gmatch(time, '(%d+):(%d+)-(%d+):(%d+)') do
            sh, sm, eh, em = tonumber(sh) or 0, tonumber(sm) or 0, tonumber(eh) or 0, tonumber(em) or 0
            local start_step = sh * 60 + sm
            local end_step = eh * 60 + em
            if start_step <= step and step <= end_step then
                return true
            end
        end
        return false
    end

    return true
end

function IS_IN_LIMIT_TIME()
    local limit = ngx.shared.limit
    local next_check_time, now_check_value = tonumber(limit:get("next_check_time")), limit:get("now_check_value")
    if next_check_time and ngx.now() < next_check_time then
        return now_check_value
    end

    local is_ok = _check_in_limit()
    limit:set("next_check_time", ngx.now() + 60)
    limit:set("now_check_value", is_ok)
    return is_ok
end

function RECORD_ACCTACK_REQUEST()
    local red = GET_REDIS_CLIENT()
    local raw_http_request = GET_RAW_HTTP_REQUEST_INFO(true)
    local key = "client_attack_url_all"
    local add_pre = GET_CLIENT_IP() .. ":_:" .. ngx.now() .. "\r\n"
    local len = red:lpush(key, add_pre .. raw_http_request)
    if len > 10000 then
        red:ltrim(key, 0, 9999)
    end
end

function GET_REDIS_CLIENT()
    local redis = require "redis.redis_helper"
    return redis:new(GLOBAL_CONFIG_INFO["redis"])
end

-- firewall forbidden command
function GET_STATIS_COMMAND()
    return GLOBAL_CONFIG_INFO["statis"]
end

function GET_SERVER_ID()
    return GLOBAL_CONFIG_INFO["server_id"]
end

function BUILD_UNIQUE_KEY(key)
    return string.format("server%s:%s", GET_SERVER_ID(), key)
end

function GET_MATCH_STAR_HOST(host)
    -- if string.match(host,'%d+.%d+.%d+.%d+') == host then
    --     return "*"
    -- end
    local dot_pos = string.find(host,".",1,true)
    if not dot_pos then
        return "*"
    end
    return "*"..string.sub(host, dot_pos)
end

function STRING_SPLIT(str, seq)
    local rt = {}
    local _ = string.gsub(str, '[^'..(seq or " ")..']+', function(w) 
        table.insert(rt, w) 
    end)
    return rt
end