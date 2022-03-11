echo "delete frobidden" >> /luojia/logs/aa.log
echo $1 >> /luojia/logs/aa.log
ipset del luojia $1
echo `date` >> /luojia/logs/aa.log