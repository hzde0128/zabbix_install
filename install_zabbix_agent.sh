#!/bin/bash
# Author:Jerry Wong
# Date: 2017-03-14
# Email:hzde0128@live.cn
CURRENT_DIR=$(dirname $(readlink -f $0))
if [ `id -u` -ne 0 ];then
	echo "请使用root身份运行"
	exit 8
fi
if [ ! -e $CURRENT_DIR/installrc ];then
    echo "缺少配置文件"
    exit 7
else
    source $CURRENT_DIR/installrc
fi
if [ $ip_addr == '' ];then
    read -p "请输入zabbix_server服务器IP地址:" ip_addr
fi
ping -c 4 ${ip_addr}
if [ $? -ne 0 ];then
    echo -e "\033[41m连接zabbix_server失败，请检查网络连接\033[0m"
    exit 7
fi
release=`cat /etc/system-release|awk -F'.' '{print $1}' | awk '{print $NF}'`
if [ -e $CURRENT_DIR/README.md ];then
    cat $CURRENT_DIR/README.md
    sleep 3
fi
#初始化安装
yum -y install ntpdate wget
echo "同步时间状态"
ntpdate pool.ntp.org
echo "创建zabix用户"
groupadd -g 105 zabbix
useradd -g 105 -u 105 -s /sbin/nologin zabbix

#安装zabbix-agent
echo "安装zabbix-${zabbix_version}"
if [ ! -f zabbix-${zabbix_version}.tar.gz ];then
    wget http://${ip_addr}/zabbix/zabbix-${zabbix_version}.tar.gz
fi
#解压
tar xf zabbix-${zabbix_version}.tar.gz
cd zabbix-${zabbix_version}
./configure --prefix=/usr/local/zabbix --enable-agent
CPU_NUM=`cat /proc/cpuinfo | grep processor | wc -l`
if [ $CPU_NUM -gt 1 ];then
    make -j${CPU_NUM}
else
    make
fi
    make install

echo "配置zabbix server ip为 ${ip_addr}"
sed -i "s/Server=127.0.0.1/Server=${ip_addr}/g" /usr/local/zabbix/etc/zabbix_agentd.conf
echo "加入启动init"
cp ${CURRENT_DIR}/zabbix-${zabbix_version}/misc/init.d/tru64/zabbix_agentd /etc/init.d/
chmod +x /etc/init.d/zabbix_agentd
sed -i "s#DAEMON=/usr/local/sbin/zabbix_agentd#DAEMON=/usr/local/zabbix/sbin/zabbix_agentd#g" /etc/init.d/zabbix_agentd
echo "启动zabbix_agentd"
/etc/init.d/zabbix_agentd start
