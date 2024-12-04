#!/bin/bash

# 启动MySQL服务
# service mysql start

# 初始化Zabbix数据库（如果需要）
# mysql -u root -ppassword -e "CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
# mysql -u root -ppassword -e "CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY 'password';"
# mysql -u root -ppassword -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
# mysql -u root -ppassword -e "FLUSH PRIVILEGES;"

# 导入Zabbix SQL脚本
# mysql -u root -ppassword zabbix < /server.sql

# 启动Zabbix Server
service zabbix-server restart

# 启动Apache Web服务器
service apache2 restart

# 启动Zabbix Agent
service zabbix-agent2 restart

# 启动Zabbix Web Service
service zabbix-web-service restart

# 持续运行以保持容器运行
tail -f /dev/null
