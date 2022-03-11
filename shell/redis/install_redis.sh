apt-get install -y gcc pkg-config make
tar -zxvf redis-6.2.3.tar.gz

cd redis-6.2.3
make -j 8
make install PREFIX=/usr/local/redis
cd ../
rm -rf redis-6.2.3

mkdir -p /etc/redis
cp redis.conf /etc/redis/redis.conf
