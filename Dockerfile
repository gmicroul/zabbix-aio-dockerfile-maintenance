# 使用最新的Ubuntu AMD64镜像作为基础镜像
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND noninteractive
# COPY sources.list /etc/apt/sources.list
# 安装所需的软件
RUN apt-get update -y && apt-get install -y wget vim locales \
 && wget https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1%2Bubuntu22.04_all.deb \
 && dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb \ 
 && apt-get update -y \
 && apt-get install -y mysql-server php php-mysql apache2 zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent2 \
 && usermod -d /var/lib/mysql/ mysql \
 && locale-gen en_US.UTF-8 \
 && update-locale
COPY my.cnf /etc/mysql/my.cnf
COPY zabbix_server.conf /etc/zabbix/zabbix_server.conf
COPY zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf
COPY apache.conf /etc/zabbix/apache.conf
COPY php.ini /etc/php/8.1/apache2/php.ini
# COPY server.sql /.
COPY server.sql.zip /.
# 配置MySQL
RUN unzip /server.sql.zip && rm -f /server.sql.zip \
 && sed -i 's/bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf \
 && service mysql restart && mysql -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;" \
 && service mysql restart && mysql -e "create user zabbix@localhost identified by 'password';" \
 && service mysql restart && mysql -e "grant all privileges on zabbix.* to zabbix@localhost;" \
 && service mysql restart && mysql -e "set global log_bin_trust_function_creators = 1;" \
 && service mysql restart && mysql -e "FLUSH PRIVILEGES;" \
 && service mysql restart && mysql -e "use zabbix;source /server.sql;" 
# 暴露Zabbix Frontend端口
EXPOSE 80 3306 11050
# 启动Apache2和Zabbix Agent
CMD service mysql restart && service zabbix-server restart && service apache2 restart && service zabbix-agent2 restart && tail -f /dev/null

