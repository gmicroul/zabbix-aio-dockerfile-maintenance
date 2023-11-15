# zabbix-aio-dockerfile-maintenance
Afer deployed zabbix you can add url monitoring as below setps:
Installation

    Shell commands prerequisites to install before using this template: openssl, curl, dos2unix
    Install and configure the main script into zabbix agent client that will test the URLs:

git clone https://github.com/ugoviti/zabbix-templates.git
cd zabbix-templates/
git pull
cd url-monitor/
ZABBIX_SCRIPTS_DIR="/etc/zabbix/scripts"
ZABBIX_AGENT_DIR="/etc/zabbix/zabbix_agent2.d"
mkdir -p $ZABBIX_SCRIPTS_DIR $ZABBIX_AGENT_DIR
cp scripts/* $ZABBIX_SCRIPTS_DIR/
chmod 755 $ZABBIX_SCRIPTS_DIR/*
cp zabbix_agent*/*.conf $ZABBIX_AGENT_DIR/

    Change Timeout settings of Zabbix Agent config file /etc/zabbix/zabbix_agent2.conf: Timeout=20 (default setting of 3 seconds is too small)
    Restart zabbix-agent: systemctl restart zabbix-agent2
    Import url-monitor_zbx_export_templates.yaml into Zabbix templates panel
    Assign Zabbix template to the host and customize the MACROS like{$URL_PATH_CSV} macro path with your CSV file and wait for automatic discovery

CSV File template example

Default file path: /etc/zabbix/url-monitor.csv


