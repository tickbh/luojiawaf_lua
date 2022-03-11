
参数说明 

limit_ip:all 值 为 aaa/bbbb 均为数字, aaa表示桶数, bbbb超出桶延时请求的最大数
limit_uri:all 值 为 aaa/bbbb 均为数字, aaa表示桶数, bbbb超出桶延时请求的最大数

not_wait_forbidden_ratio 默认为0.9, 规则判断错序的比例
not_wait_forbidden_min_len 默认为20, 规则判断错序最小值

min_all_visit_times 默认为20, 规则判定总访问次数的起点值
max_visit_idx_num 默认为2, 排序最高的前两台占比
max_visit_ratio 默认为0.85, 即前2条访问量占总比值的比例

default_forbidden_time 默认为600即10分钟, 禁用ip的默认时长

white_ip_check 白名单检查 on 为开启
forbidden_ip_check IP禁止检查 on 为开启
limit_ip_check IP限制检查 on 为开启
limit_uri_check uri限制检查 on 为开启
white_url_check 白url检查 on 为开启

post_attack_check post参数攻击请求on 为开启
url_args_attack urls参数攻击请求on 为开启

random_record_value 随机记录的值, 100%则填10000

---------------------------------------------------------

iptables -L INPUT --line-numbers
iptables -D INPUT 12
---------------------------------------------------------

iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 59736 -s xx.xx.xx.xx -j ACCEPT
iptables -A INPUT -p tcp --dport 59736 -j REJECT

安装ipset
debian系统
apt-get install ipset -y
配置iptables
默认过期时间1小时
ipset create luojiawaf hash:net hashsize 4096 maxelem 200000 timeout 3600
iptables -I INPUT -m set --match-set luojiawaf src -p tcp -j REJECT











firewall-cmd --permanent --add-source=47.100.32.153

firewall-cmd --permanent --remove-source=47.100.32.153


 firewall-cmd --permanent --remove-rich-rule 'rule family="ipv4" port port="6379" protocol="tcp" reject'


 firewall-cmd --permanent --remove-rich-rule ' rule family="ipv4" source address="47.100.32.153" port port="6379" protocol="tcp" accept'

 firewall-cmd --permanent --zone=drop --add-port=6379/tcp

firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="6379" protocol="tcp" reject'

dockerd --dns 114.114.114.114


docker 影响 firewalld情况

#修改/usr/lib/systemd/system/docker.service

$vi /usr/lib/systemd/system/docker.service

#找到 ExecStart=/usr/bin/dockerd -H fd://xxxxxxxxxxxxxxxx 在中间添加 --iptables=false
修改之后 :
	ExecStart=/usr/bin/dockerd --iptables=false -H fd://xxxxxxxxxxxxxxxx

$:wq 保存退出

#然后
$ systemctl daemon-reload
$ systemctl restart docker


firewall-cmd --permanent --new-zone=docker
firewall-cmd --permanent --zone=docker --change-interface=docker0
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address=172.18.0.0/16 masquerade'
firewall-cmd --reload



systemctl stop NetworkManager

systemctl disable NetworkManager


export PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin
export LUA_PATH="/usr/local/openresty/site/lualib/?.ljbc;/usr/local/openresty/site/lualib/?/init.ljbc;/usr/local/openresty/lualib/?.ljbc;/usr/local/openresty/lualib/?/init.ljbc;/usr/local/openresty/site/lualib/?.lua;/usr/local/openresty/site/lualib/?/init.lua;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/lualib/?/init.lua;./?.lua;/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua"
export LUA_CPATH="/usr/local/openresty/site/lualib/?.so;/usr/local/openresty/lualib/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so"


git config --global credential.helper store 