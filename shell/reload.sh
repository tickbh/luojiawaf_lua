cp -f ../nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
echo "copy nginx.conf success"

/usr/local/openresty/nginx/sbin/nginx -s reload
echo "reload success"
