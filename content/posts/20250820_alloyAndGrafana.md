+++
title = "Using Alloy and Grafana for extracting metrics and pushing to dashboard"
description = "Using Alloy and Grafana for extracting metrics and pushing to dashboard"
tags = [
    "devops",
    "google-cloud",
]
date = "2025-08-20"
categories = [
    "devops",
    "google-cloud",
]
+++

I need to deploy a metrics exporter to check for nodes on instances and push it into a grafana metrics dashboard

We can demonstrate this with 2 instances

## Deploy alloy to collect Node Metrics

We would first install alloy of the instance we would want to monitor. Here are the reference for it: https://grafana.com/docs/alloy/latest/set-up/install/linux/

```bash
sudo apt install gpg
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install alloy
sudo systemctl enable alloy
sudo systemctl start alloy
```

We would need to reconfigure alloy configuration: `/etc/alloy/config.alloy`

```
// Sample config for Alloy.
//
// For a full configuration reference, see https://grafana.com/docs/alloy
logging {
  level = "info"
}

prometheus.exporter.unix "default" {
  include_exporter_metrics = true
  disable_collectors       = ["mdadm"]
}

prometheus.scrape "default" {
  targets = array.concat(
    prometheus.exporter.unix.default.targets,
    [{
      // Self-collect metrics
      job         = "alloy",
      __address__ = "127.0.0.1:12345",
    }],
  )

  forward_to = [
        prometheus.remote_write.default.receiver,
  ]
}

prometheus.remote_write "default" {
  endpoint {
    url = "http://10.X.X.X:9090/api/v1/write"
  }
}
```

## Deploy prometheus and grafana on Second instance

This is to install grafana

```bash
sudo apt-get install -y apt-transport-https software-properties-common wget
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
# Updates the list of available packages
sudo apt-get update
# Installs the latest OSS release:
sudo apt-get install grafana
sudo systemctl enable grafana
sudo systemctl start grafana
```

This is to install prometheus

```bash
sudo useradd -M -U prometheus

wget https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz
tar -xzvf prometheus-3.5.0.linux-amd64.tar.gz
sudo mv prometheus-3.5.0.linux-amd64 /opt/prometheus
sudo chown prometheus:prometheus -R /opt/prometheus
```

We then need to create prometheus systemd file in the following file: `/etc/systemd/system/prometheus.service`.

```
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Restart=on-failure
ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --web.enable-remote-write-receiver \
  --storage.tsdb.path=/opt/prometheus/data \
  --storage.tsdb.retention.time=30d

[Install]
WantedBy=multi-user.target
```

Take note of the above that for the above prometheus, we would allow it to accept metrics from other sources

In order to expose the grafana, we may need to ensure that port 3000 is exposed publicly (we can't exactly easily use port 80 - this would mean grafana would need to be run by root user).

## Conclusion

After which, when we start everything, we can then check if everything is setup correctly. We can do so by doing the following:

- Login in grafana with default credentials (admin / admin)
- Add the node exporter dashboard 1860 - https://grafana.com/grafana/dashboards/1860-node-exporter-full/
- Check that the metrics is coming in via the Explore panel (Grafana)