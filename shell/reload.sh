cp -f $PWD/../nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
echo "copy nginx.conf success"

/usr/local/openresty/nginx/sbin/nginx -s reload -c /usr/local/openresty/nginx/conf/nginx.conf
echo "send reload singal"
sleep 1
ps -ef | grep nginx
