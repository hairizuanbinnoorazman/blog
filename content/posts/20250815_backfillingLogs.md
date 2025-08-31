+++
title = "Backfilling logs on Loki (Grafana Stack)"
description = "Backfilling logs on Loki (Grafana Stack)"
tags = [
    "devops",
    "docker",
]
date = "2025-08-15"
categories = [
    "devops",
    "docker",
]
+++

I have a small engineering problem to resolve which to export logs from an android application and save it into a monitoring stack of sorts. The logs are mostly only for debugging purposes because its a pure pain to try to go chat with the user that holds the phone in order to debug the issue. Technically, I can use tools like sentry that is able to retrieve logs more automatically but that would require a bit more involvement with sending logs more consistently to the cloud. The application as of now generates too much logs over long periods so there is a slight fear that if I enable that, it might take too much bandwidth from the android application. (I guess I also need to mention that the application would be operating with a very limited bandwidth - logs are a nice to have and only used in debugging cases -  which is technically not often)

Right now, I have an idea which is to have the android app to export logs for a time period, zip it and send it over to the server which would then send to my monitoring stack (which is the usual Grafana stack - who doesn't use them)

The following blog post is only to do part 1 of this entire endeavour which is to push logs to the monitoring stack - maybe I'll cover in another blog post off a simple code that one can add in a android to zip logs and send it to server for doing such parsing and processing to send it to the monitoring stack.

Here is a setup that can be used to test this.

Here is the docker compose setup for it:

```yaml
version: "3.8"

services:
  loki:
    image: grafana/loki:2.9.2
    container_name: loki
    # It keeps complaining of being unable to mkdir folders due to permissions
    user: "0"
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - ./hehe2.yaml:/etc/loki/local-config.yaml:ro
      - loki-folder:/loki

  grafana:
    image: grafana/grafana:10.2.3
    container_name: grafana
    ports:
      - "3000:3000"
    depends_on:
      - loki
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  grafana-data:
  loki-folder:
```

I'll need to add the grafana datasource manually for the above setup via UI.

Here is the loki config file (saved as `hehe2.yaml`):

```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s
  max_transfer_retries: 0

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

compactor:
  working_directory: /loki/compactor
  shared_store: filesystem

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

After the setup above is done, one can run the following curl request:

```bash
curl -X POST "http://localhost:3100/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d '{
    "streams": [
      {
        "stream": {
          "job": "demo",
          "app": "example"
        },
        "values": [
          ["1756655381000000000", "This is a backfilled log line"]
        ]
      }
    ]
  }'
```

The timestamp is a nano time stamp

We would probably need to modify the timestamp field if we want to reuse the above example; take note that we allowed loki to reject old samples data - we only accept old sample data that is only up to 168hours back.