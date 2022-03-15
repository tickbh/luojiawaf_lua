/usr/local/openresty/nginx/sbin/nginx -c /usr/local/openresty/nginx/conf/nginx.conf
echo "send start singal"
sleep 1
ps -ef | grep nginx
