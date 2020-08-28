# Asterisk Exporter

This script collects basic metrics from Asterisk and exposes them through [node_exporter](https://github.com/prometheus/node_exporter)

### Requirements:
- node_exporter running with --collector.textfile.directory set
- Systemd (to run it as a service with the following instructions)

### Installation:
- edit asterisk_exporter.sh, changing the value of "METRIC_FILE" to point to the folder specified on "--collector.textfile.directory"
- edit asterisk_exporter.service, setting the appropriate "User" and current "ExecStart", which points to asterisk_exporter.sh
- run the following commands to enable and start the service:

     ```
    chmod 0755 asterisk_exporter.sh
    cp asterisk_exporter.service /etc/systemd/system
    systemctl daemon-reload
    systemctl enable asterisk_exporter    
    systemctl start asterisk_exporter
    ```


