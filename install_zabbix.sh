#!/bin/bash
# Author:Jerry Wong
# Date: 2017-03-14
# Email:hzde0128@live.cn
CURRENT_DIR=$(dirname $(readlink -f $0))
if [ ! -e $CURRENT_DIR/installrc ];then
    echo "缺少配置文件"
    exit 7
else
    source $CURRENT_DIR/installrc
fi
ip_addr_count=`ip addr | grep inet | grep -Ev 'inet6|127' | awk -F'/' '{print $1}' | awk '{print $NF}' | wc -l`
if [ $ip_addr_count -eq 1 ];then
    ip_addr=`ip addr | grep inet | grep -Ev 'inet6|127' | awk -F'/' '{print $1}' | awk '{print $NF}'`
fi
release=`cat /etc/system-release|awk -F'.' '{print $1}' | awk '{print $NF}'`
if [ -e $CURRENT_DIR/README.md ];then
    cat $CURRENT_DIR/README.md
    sleep 3
fi
#初始化安装
if [ $release = 7 ];then
    yum -y install epel-release
    yum -y install php-xml php-xmlrpc php-mbstring php-mhash patch java-devel wget unzip libxml2 libxml2-devel httpd mariadb mariadb-devel mariadb-server php php-mysql php-common php-mbstring php-gd php-odbc php-pear curl curl-devel net-snmp net-snmp-devel perl-DBI php-xml ntpdate  php-bcmath zlib-devel glibc-devel curl-devel gcc automake libidn-devel openssl-devel net-snmp-devel rpm-devel OpenIPMI-devel
    systemctl start mariadb.service
elif [ $release = 6 ];then
    yum -y remove php php-cli php-common php-gd php-ldap php-mbstring php-mcrypt php-mysql php-pdo
    yum -y install epel-release
    rpm -Uvh http://mirror.webtatic.com/yum/el6/latest.rpm
    yum -y install patch java-devel wget unzip libxml2 libxml2-devel httpd mysql mysql-server  curl curl-devel net-snmp net-snmp-devel perl-DBI ntpdate zlib-devel mysql-devel glibc-devel gcc-c++ gcc automake mysql libidn-devel openssl-devel net-snmp-devel rpm-devel OpenIPMI-devel php56w php56w-cli php56w-common php56w-gd php56w-ldap php56w-mbstring php56w-mcrypt php56w-mysql php56w-pdo php56w-bcmath php56w-xml 
    service mysqld start
fi

echo "同步时间状态"
ntpdate pool.ntp.org
echo "创建zabix用户"
groupadd -g 105 zabbix
useradd -g 105 -u 105 -s /sbin/nologin zabbix

echo "设置MySQL数据库root密码,修改为${mysql_pass}"
mysqladmin -uroot password ${mysql_pass}

echo "创建zabbix数据库、用户名和密码"
mysql -uroot -p${mysql_pass} -e "CREATE DATABASE IF NOT EXISTS zabbix DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"
mysql -uroot -p${mysql_pass} -e "GRANT ALL ON zabbix.* to zabbix@'localhost' IDENTIFIED BY 'zabbix';"
mysql -uroot -p${mysql_pass} -e "FLUSH PRIVILEGES;"

echo "安装zabbix-${zabbix_version}"
if [ ! -f zabbix-${zabbix_version}.tar.gz ];then
    wget https://jaist.dl.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/3.0.8/zabbix-3.0.8.tar.gz
fi
#解压
tar xf zabbix-${zabbix_version}.tar.gz
cd zabbix-${zabbix_version}
./configure --prefix=/usr/local/zabbix --enable-server --enable-agent --with-mysql --with-net-snmp --with-lib-curl --with-libxml2 --enable-java
CPU_NUM=`cat /proc/cpuinfo | grep processor | wc -l`
if [ $CPU_NUM -gt 1 ];then
    make -j${CPU_NUM}
else
    make
fi
    make install
mkdir /var/www/html/zabbix
cp -r $CURRENT_DIR/zabbix-${zabbix_version}/frontends/php/* /var/www/html/zabbix
if [ -e $CURRENT_DIR/simkai.ttf ];then
    cp $CURRENT_DIR/simkai.ttf /var/www/html/zabbix/fonts
fi
sed -i "s/DejaVuSans/simkai/g" /var/www/html/zabbix/include/defines.inc.php

echo "创建zabbix数据库配置文档"
rm -f /var/www/html/zabbix/conf/zabbix.conf.php
cat > /var/www/html/zabbix/conf/zabbix.conf.php <<END
<?php
// Zabbix GUI configuration file.
global \$DB;
\$DB['TYPE']     = 'MYSQL';
\$DB['SERVER']   = 'localhost';
\$DB['PORT']     = '3306';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER']     = 'zabbix';
\$DB['PASSWORD'] = 'zabbix';
// Schema name. Used for IBM DB2 and PostgreSQL.
\$DB['SCHEMA'] = '';
\$ZBX_SERVER      = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = '';
\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
?>
END

echo "导入zabbix数据库"
cd $CURRENT_DIR/zabbix-${zabbix_version}
mysql -uzabbix -pzabbix zabbix < database/mysql/schema.sql
mysql -uzabbix -pzabbix zabbix < database/mysql/images.sql
mysql -uzabbix -pzabbix zabbix < database/mysql/data.sql
if [ -e /var/www/html/zabbix/fonts/simkai.ttf ];then
    mysql -uroot -p${mysql_pass} zabbix -e "update users set lang='zh_CN' where alias='Admin';"
fi

echo "设置开机自启动"
cp $CURRENT_DIR/zabbix-${zabbix_version}/misc/init.d/tru64/zabbix_agentd /etc/init.d/
cp $CURRENT_DIR/zabbix-${zabbix_version}/misc/init.d/tru64/zabbix_server /etc/init.d/
chmod +x /etc/init.d/zabbix_*
sed -i 's#DAEMON=/usr/local/sbin/zabbix_server#DAEMON=/usr/local/zabbix/sbin/zabbix_server#g' /etc/init.d/zabbix_server
sed -i 's#DAEMON=/usr/local/sbin/zabbix_agentd#DAEMON=/usr/local/zabbix/sbin/zabbix_agentd#g' /etc/init.d/zabbix_agentd
sed -i 's#DBUser=root#DBUser=zabbix#g' /usr/local/zabbix/etc/zabbix_server.conf
sed -i '/# DBPassword=/a\DBPassword=zabbix' /usr/local/zabbix/etc/zabbix_server.conf

echo "修改php.ini文件"
cp /etc/php.ini /etc/php.ini.zabbixbak
sed -i 's/max_execution_time = 30/max_execution_time = 300/g' /etc/php.ini
sed -i '/max_input_time =/s/60/300/' /etc/php.ini
sed -i '/mbstring.func_overload = 0/a\mbstring.func_overload = 1' /etc/php.ini
sed -i '/post_max_size =/s/8M/32M/' /etc/php.ini
sed -i '/;always_populate_raw_post_data = -1/a\always_populate_raw_post_data = -1' /etc/php.ini
sed -i '/;date.timezone =/a\date.timezone = PRC' /etc/php.ini

echo "配置apache"
sed -i '/#ServerName www.example.com:80/a\ServerName zabbix-server' /etc/httpd/conf/httpd.conf 
if [ $listen_port -ne 80 ];then
    sed -i '/Listen 80/Listen $listen_port/' /etc/httpd/conf/httpd.conf
fi
if [ $release = 7 ];then
    systemctl enable httpd.service
    systemctl start httpd.service
elif [ $release = 6 ];then
    chkconfig --add httpd
    chkconfig httpd on
    service httpd start
fi

echo "启动zabbix"
/etc/init.d/zabbix_server restart
/etc/init.d/zabbix_agentd restart
/usr/local/zabbix/sbin/zabbix_java/startup.sh
echo "zabbix-Database name:zabbix/User:zabbix/Password:zabbix"
cp $CURRENT_DIR/zabbix-${zabbix_version}.tar.gz /var/www/html/zabbix
if [ $listen_port -eq 80 ];then
    echo "打开http://$ip_addr/zabbix，进行下一步的配置"
elif [ $? -eq 0 ];then
    echo "打开http://$ip_addr:$listen_port/zabbix，进行下一步的配置"
fi
else
    echo "
fi
echo "Web页面登录用户名:Admin密码:zabbix"
