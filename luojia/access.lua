require 'init'
require 'lib'

-- 添加指定时间内限流, 防止高峰情况, 日期, 星期, 时间段
-- 指定url进行限流, 防止服务器高并发无法处理
-- 自动防火墙封禁IP

local function waf_main()
    ngx.update_time()
    if WHITE_IP_CHECK() then
    elseif WHITE_URL_CHECK() then
    elseif FORBIDDEN_IP_CHECK() then
    elseif LIMIT_IP_CHECK() then
    elseif LIMIT_URI_CHECK() then
    elseif POST_ATTACK_CHECK() then
    elseif URL_ARGS_ATTACK_CHECK() then
    end
end

waf_main()

