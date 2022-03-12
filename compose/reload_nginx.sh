# git pull && docker-compose build
#docker cp nginx/nginx.conf nginx-docker:/etc/nginx/conf.d/nginx.conf
docker exec -it waf_server-docker nginx -s reload