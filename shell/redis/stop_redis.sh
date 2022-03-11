#!/bin/sh

redis_pid="/var/run/redis_6379.pid"
if [ -f "$redis_pid" ]; then
    kill -9 $(cat $redis_pid)
    rm -f $redis_pid
fi
echo "ok"
ps -ef | grep redis-server