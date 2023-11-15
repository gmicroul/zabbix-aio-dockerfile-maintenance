# 使用最新的Ubuntu ARM64镜像作为基础镜像
FROM ubuntu:latest
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y wget vim locales
# 安装所需的软件包
COPY sources.list /etc/apt/sources.list
RUN apt-get update -y
RUN wget https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1%2Bubuntu22.04_all.deb
RUN dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb 
RUN apt-get update && apt-get install -y \
    mysql-server php php-mysql apache2 zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent zabbix-agent2
RUN ls /usr/share/zabbix-sql-scripts/mysql/
RUN usermod -d /var/lib/mysql/ mysql
COPY my.cnf /etc/mysql/my.cnf
COPY zabbix_server.conf /etc/mysql/zabbix_server.conf
COPY zabbix_agentd.conf /etc/mysql/zabbix_agentd.conf
COPY zabbix_agent2.conf /etc/mysql/zabbix_agent2.conf
COPY apache.conf /etc/zabbix/apache.conf
COPY php.ini /etc/php/8.1/apache2/php.ini

RUN locale-gen en_US.UTF-8 && update-locale

# 配置MySQL
RUN sed -i 's/bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf

RUN service mysql restart && mysql -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
RUN service mysql restart && mysql -e "create user zabbix@localhost identified by 'password';" 
RUN service mysql restart && mysql -e "grant all privileges on zabbix.* to zabbix@localhost;" 
RUN service mysql restart && mysql -e "set global log_bin_trust_function_creators = 1;" 
#RUN zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p zabbix 
#RUN service mysql restart && mysql -e "--default-character-set=utf8 -uzabbix -p zabbix;"
#RUN service mysql start && mysql -e "create database zabbix character set utf8 collate utf8_bin;"
#RUN service mysql restart && mysql -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'password';"
#RUN service mysql restart && mysql -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
RUN service mysql restart && mysql -e "FLUSH PRIVILEGES;"
COPY server.sql /.
RUN service mysql restart && mysql -e "use zabbix;source /server.sql;" 
#    && mysql -e "use zabbix;source /images.sql;" \
#    && mysql -e "use zabbix;source /data.sql;"

# 配置Zabbix Server
#RUN sed -i 's/# DBHost=localhost/DBHost=localhost/' /etc/zabbix/zabbix_server.conf
#RUN sed -i 's/# DBPassword=/DBPassword=password/' /etc/zabbix/zabbix_server.conf

# 配置Zabbix Frontend
#RUN sed -i 's/# php_value date.timezone Europe\/Riga/php_value date.timezone Asia\/Shanghai/' /etc/zabbix/apache.conf
#RUN cp -r /usr/share/zabbix /var/www/html/

# 配置Zabbix Agent
#RUN sed -i 's/Server=127.0.0.1/Server=zabbix-server/' /etc/zabbix/zabbix_agentd.conf
#RUN sed -i 's/ServerActive=127.0.0.1/ServerActive=zabbix-server/' /etc/zabbix/zabbix_agentd.conf

# 暴露Zabbix Frontend端口
EXPOSE 80 3306 11050

# 启动Apache2和Zabbix Agent
CMD service mysql restart && service zabbix-server restart && service apache2 restart && service zabbix-agent restart && service zabbix-agent2 restart && tail -f /dev/null

