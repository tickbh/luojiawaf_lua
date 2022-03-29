--waf status
CONFIG_WAF_ENABLE = "on"
--log dir
CONFIG_LOG_DIR = "/luojia/logs"
--rule setting
CONFIG_RULE_DIR = "/luojia/luojia/rule-config"
--rule setting
CONFIG_PUBLIC = "/luojia/public"

SOURCE_VERSION = "1.0"

--config waf output redirect/html
CONFIG_WAF_OUTPUT = "html"
--if config_waf_output ,setting url
CONFIG_WAF_REDIRECT_URL = "https://tool.fit"
CONFIG_OUTPUT_HTML=[[
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Content-Language" content="zh-cn" />
<title>洛甲WAF-Web应用防火墙</title>
</head>
<body>
<h2 align="center"> 您的IP为:local_client_ip </h2>
<h3 align="center"> 您的IP存在异常访问的情况, 若误封, 请联系管理员 </h3>
<h4 align="center"> 洛甲WAF为您的服务提供保驾护航 </h4>
</body>
</html>
]]

CONFIG_TOOFASTER_HTML=[[
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Content-Language" content="zh-cn" />
<title>洛甲WAF-Web应用防火墙</title>
</head>
<body>
<h3 align="center"> 请坐下来喝杯茶吧, 您请求的太快了 </h3>
<h4 align="center"> 洛甲WAF为您的服务提供保驾护航 </h4>
</body>
</html>
]]

function GET_CONFIG_DATA_BY_KEY(key, default)
    local value = ngx.shared.cache_dict:get("config_"..key)
    return value or default
end

function GET_CONFIG_WHITE_IP()
    return GET_CONFIG_DATA_BY_KEY("white_ip_check", "on")
end

function GET_CONFIG_FORBIDDEN_IP()
    return GET_CONFIG_DATA_BY_KEY("forbidden_ip_check", "on")
end

function GET_CONFIG_LIMIT_IP()
    return GET_CONFIG_DATA_BY_KEY("limit_ip_check", "on")
end

function GET_CONFIG_LIMIT_URL()
    return GET_CONFIG_DATA_BY_KEY("limit_uri_check", "on")
end

function GET_CONFIG_WHITE_URI()
    return GET_CONFIG_DATA_BY_KEY("white_uri_check", "on")
end

function GET_CONFIG_POST_ATTACK()
    return GET_CONFIG_DATA_BY_KEY("post_attack_check", "on")
end

function GET_CONFIG_URL_ARGS_ATTACK()
    return GET_CONFIG_DATA_BY_KEY("url_args_attack", "on")
end

function GET_CONFIG_USER_AGENT()
    return GET_CONFIG_DATA_BY_KEY("user_agent_check", "on")
end

function GET_CONFIG_FORBIDDEN_RECORD()
    return GET_CONFIG_DATA_BY_KEY("config_forbidden_record", "on")
end

function GET_CONFIG_STREAM_LIMIT()
    return GET_CONFIG_DATA_BY_KEY("stream_limit_check", "off")
end

function GET_CONFIG_UPSTREAM_METHOD()
    return GET_CONFIG_DATA_BY_KEY("upstream_method", "random")
end

function GET_CONFIG_DEFAULT_FORBIDDEN_TIME()
    return GET_CONFIG_DATA_BY_KEY("default_forbidden_time", 600)
end

function GET_CONFIG_LIMIT_ALL_IP()
    return GET_CONFIG_DATA_BY_KEY("limit_ip:all", nil)
end

function GET_CONFIG_LIMIT_ONE_IP(ip)
    return GET_CONFIG_DATA_BY_KEY("limit_ip:" .. ip, nil)
end

function GET_CONFIG_LIMIT_ALL_URI()
    return GET_CONFIG_DATA_BY_KEY("limit_uri:all", nil)
end

function GET_CONFIG_LIMIT_ONE_URI(uri)
    return GET_CONFIG_DATA_BY_KEY("limit_uri:" .. uri, nil)
end

function GET_CONFIG_LIMIT_WEEKDAY()
    return GET_CONFIG_DATA_BY_KEY("limit_wd", nil)
end

function GET_CONFIG_LIMIT_TIME()
    return GET_CONFIG_DATA_BY_KEY("limit_time", nil)
end

function GET_FORBIDDEN_BY_FIREWALL_TIMES()
    return tonumber(GET_CONFIG_DATA_BY_KEY("forbidden_by_firewall_times", 20)) or 20
end

function GET_RANDOM_RECORD_VALUE()
    return tonumber(GET_CONFIG_DATA_BY_KEY("random_record_value", 100)) or 100
end

function GET_IN_LIMIT(host)
    return (tonumber(GET_CONFIG_DATA_BY_KEY("in_limit:" .. host, 0)) or 0) * 1048576
end

function GET_OUT_LIMIT(host)
    return (tonumber(GET_CONFIG_DATA_BY_KEY("out_limit:" .. host, 0)) or 0) * 1048576
end

GLOBAL_CONFIG_INFO = {redis={
    host="127.0.0.1", port=6379
}}