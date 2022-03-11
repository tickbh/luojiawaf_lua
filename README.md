## 洛甲WAF
> 基于openresty的web防火墙，通过配合后台保护您的数据安全

## 快速开始  
由于docker不能得到真实的IP地址，暂时不支持在docker部署
依赖redis做数据缓存及与后端的数据通讯
### 安装redis(debian其它的类似)
进入shell/redis/运行./install_redis.sh, 通过start_redis.sh进行启动
### 安装openresty
进入shell/运行./install.sh, 安装完后，通过start.sh进行启动
### 配置防火墙信息
```
#安装ipset，如果被封的IP直接通过防火墙进行封禁
apt-get install ipset -y
ipset create luojia hash:net hashsize 4096 maxelem 200000 timeout 3600
iptables -I INPUT -m set --match-set luojia src -p tcp -j REJECT

iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
#对指定IP(后端服务器)放行redis的端口, 配置防火墙, 保证安全, 非白名单IP直接封禁
iptables -A INPUT -p tcp --dport 59736 -s xx.xx.xx.xx -j ACCEPT
iptables -A INPUT -p tcp --dport 59736 -j REJECT
```


## 💬 社区交流

##### QQ交流群

加QQ群号 684772704, 验证信息: luojiawaf
