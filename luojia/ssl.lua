local ssl = require "ngx.ssl"
local host = ssl.server_name()
local string_find = string.find
local string_sub = string.sub
local ssl_host = nil

ngx.log(ngx.ERR, "add ssl " .. (host or "empty"))
if not host then
  return ngx.exit(444)
end

local match_host = host
local function get_key_cache(h)
    return string.format("ssl:key:%s", h)
end

local function get_pem_cache(h)
    return string.format("ssl:pem:%s", h)
end

if not ngx.shared.cache_dict:ttl(get_key_cache(match_host)) then
    local star_host = GET_MATCH_STAR_HOST(match_host)
    if ngx.shared.cache_dict:ttl(get_key_cache(star_host)) then
        match_host = star_host
    else
        return ngx.exit(444)
    end
end

local clear_ok, clear_err = ssl.clear_certs()
if not clear_ok then
    ngx.log(ngx.ERR, "failed to clear existing (fallback) certificates: ",clear_err..",server_name is "..host)
    return ngx.exit(444)
end
local pem_cert_chain = assert(ngx.shared.cache_dict:get(get_pem_cache(match_host)))
local der_cert_chain, err = ssl.cert_pem_to_der(pem_cert_chain)
if not der_cert_chain then
    ngx.log(ngx.ERR, "failed to convert certificate chain ","from PEM to DER: ", err..",server_name is "..host)
    return ngx.exit(444)
end
local set_ok, set_err = ssl.set_der_cert(der_cert_chain)
if not set_ok then
    ngx.log(ngx.ERR, "failed to set DER cert: ", set_err..",server_name is "..host)
    return ngx.exit(444)
end
local pem_pkey = assert(ngx.shared.cache_dict:get(get_key_cache(match_host)))
local der_pkey, der_err = ssl.priv_key_pem_to_der(pem_pkey)
if not der_pkey then
    ngx.log(ngx.ERR, "failed to convert private key ","from PEM to DER: ", der_err..",server_name is "..host)
    return ngx.exit(444)
end
local set_key_ok, set_key_err = ssl.set_der_priv_key(der_pkey)
if not set_key_ok then
    ngx.log(ngx.ERR, "failed to set DER private key: ", set_key_err..",server_name is "..host)
    return ngx.exit(444)
end

ngx.log(ngx.ERR, "load ssl: " .. host.." ok")