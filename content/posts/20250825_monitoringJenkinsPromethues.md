+++
title = "Monitoring Jenkins via Prometheus"
description = "Monitoring Jenkins via Prometheus"
tags = [
    "devops",
    "jenkins",
]
date = "2025-08-25"
categories = [
    "devops",
    "jenkins",
]
+++

It is pretty important to understand how our jenkins job is running. We can technically keep querying the jenkins server via jenkins API but that would mean trying to parse the every changing response - which could be quite a painful process to go through. Instead, what we can do is to simply install 2 plugins - `metrics` and `prometheus` jenkins plugins.

I have a small setup to demonstrate this with a jenkins setup that will setup the following in a docker-compose setup

- Jenkins master in a container
- Jenkins agent in a container
- Prometheus (to collect metrics)
- Grafana to vizualize that data from the prometheus

Reference to the setup is here: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Environment/jenkins

## Important step 1: Install required plugins

There are a few critical steps just for doing the monitoring of jenkins via promethues. The first would be install the metrics and prometheus plugins. Technically we can do this via Jenkins UI but with the setup mentioned above, we can do it "automatically" - we can define it in the `plugins.txt` mentioned in the following file in the above repo: https://github.com/hairizuanbinnoorazman/Go_Programming/blob/master/Environment/jenkins/plugins.txt

With that, we would install it during docker build step and it would be available on next start of jenkins master and slave servers.

## Important step 2: Querying of prometheus data

The prometheus data is possible to be queried by querying the `<host>:<port>/prometheus/` endpoint (but its possible to configure it differently as well). Refer to the following plugin page: https://plugins.jenkins.io/prometheus/

For prometheus, we can set the configuration of the prometheus with static configuration. Since we're doing the above setup via docker compose setup - we can see that the jenkins master server can be reached and pinged with `jenkins` hostname. 

```yaml
global:
  scrape_interval: 1m
  evaluation_interval: 1m

# A list of scrape configurations.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to all metrics scraped from this config.
  - job_name: 'jenkins'

    static_configs:
      - targets: ['jenkins:8080']
        metrics_path: "/prometheus"
```

The jenkins server is exposed via port 8080. For the metrics, it is exposed on `/prometheus` instead of the usual `/metrics` path.

Technically this is enough to get something started with data collection. Actual vizualization of the metrics collection on grafana

## Important step 3: Viewing of jenkins data on grafana

We can then hook the grafana setup to the prometheus server. To check that metrics are collected correctly. Once the metrics collected, we can then use the following dashboard: https://grafana.com/grafana/dashboards/9964-jenkins-performance-and-health-overview/ to try to get something going.