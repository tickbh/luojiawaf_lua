/usr/local/redis/bin/redis-server /etc/redis/redis.conf --daemonize yes
echo "ok"
ps -ef | grep redis-server