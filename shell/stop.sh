/usr/local/openresty/nginx/sbin/nginx -s stop -c /usr/local/openresty/nginx/conf/nginx.conf
echo "send stop singal"
sleep 1
ps -ef | grep nginx