#!/bin/bash
service mysql restart && service zabbix-server restart && service apache2 restart && service zabbix-agent2 restart && service zabbix-web-service restart && tail -f /dev/null
