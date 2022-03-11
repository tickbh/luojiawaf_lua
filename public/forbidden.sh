echo "$1" >> /luojia/logs/aa.log
echo "$2" >> /luojia/logs/aa.log
ipset add luojia $1 timeout $2
echo `date` >> /luojia/logs/aa.log
