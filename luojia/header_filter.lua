require 'init'
require 'lib'

local function waf_header_filter()
    ngx.update_time();
    local secs = ngx.now()
    ngx.header["Server"] = "cc server"
    return true;
end

waf_header_filter()

