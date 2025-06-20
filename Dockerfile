# 使用最新的Ubuntu AMD64镜像作为基础镜像
FROM arm64v8/ubuntu:24.04
ENV DEBIAN_FRONTEND noninteractive
# 设置时区为东八区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# COPY sources.list /etc/apt/sources.list
# 安装所需的软件
# RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d 
RUN apt-get update -y && apt-get install -y wget vim locales lsb-release git openssl curl dos2unix \
# wget https://repo.zabbix.com/zabbix/7.0/ubuntu-arm64/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu24.04_all.deb
# dpkg -i zabbix-release_latest+ubuntu24.04_all.deb
# apt update
# apt install zabbix-agent2 zabbix-agent2-plugin-*
 && wget https://repo.zabbix.com/zabbix/7.0/ubuntu-arm64/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu24.04_all.deb \
 && dpkg -i zabbix-release_latest+ubuntu24.04_all.deb \ 
 && apt-get update -y \
 && apt-get install -y unzip mysql-server php php-mysql apache2 zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-web-service zabbix-sql-scripts zabbix-agent2 zabbix-agent2-plugin-* \
 && usermod -d /var/lib/mysql/ mysql \
 && locale-gen en_US.UTF-8 \
 && update-locale
COPY my.cnf /etc/mysql/my.cnf
COPY zabbix_server.conf /etc/zabbix/zabbix_server.conf
COPY zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf
COPY zabbix_web_service.conf /etc/zabbix/zabbix_web_service.conf
COPY apache.conf /etc/zabbix/apache.conf
COPY php.ini /etc/php/8.3/apache2/php.ini
# COPY server.sql /.
# COPY server.sql.zip /.
# 配置MySQL
RUN gunzip /usr/share/zabbix-sql-scripts/mysql/server.sql.gz && cp /usr/share/zabbix-sql-scripts/mysql/server.sql /. \
# RUN unzip /server.sql.zip && rm -f /server.sql.zip \
 && sed -i 's/bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf \
 && service mysql restart && mysql -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;" \
 && service mysql restart && mysql -e "create user zabbix@localhost identified by 'password';" \
 && service mysql restart && mysql -e "grant all privileges on zabbix.* to zabbix@localhost;" \
 && service mysql restart && mysql -e "set global log_bin_trust_function_creators = 1;" \
 && service mysql restart && mysql -e "FLUSH PRIVILEGES;" \
 && service mysql restart && mysql -e "use zabbix;source /server.sql;" \
 && cp -r /usr/share/zabbix/ /var/www/html/
RUN git clone https://github.com/ugoviti/zabbix-templates.git \
  && cd zabbix-templates/ \
  && git pull \
  && cd url-monitor/ \
  && ZABBIX_SCRIPTS_DIR="/etc/zabbix/scripts" \
  && ZABBIX_AGENT_DIR="/etc/zabbix/zabbix_agent2.d" \
  && mkdir -p $ZABBIX_SCRIPTS_DIR $ZABBIX_AGENT_DIR \
  && cp scripts/* $ZABBIX_SCRIPTS_DIR/ \
  && chmod 755 $ZABBIX_SCRIPTS_DIR/* \
  && cp zabbix_agent*/*.conf $ZABBIX_AGENT_DIR/ 
# 暴露Zabbix Frontend端口

EXPOSE 80 3306 10050 10051 10052 10053 5000 11434

# 使用tini作为入口点
ADD https://github.com/krallin/tini/releases/download/v0.19.0/tini-arm64 /sbin/tini
RUN chmod +x /sbin/tini

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
