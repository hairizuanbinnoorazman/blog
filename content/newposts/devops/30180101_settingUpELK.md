+++
title = "Setting up ELK stack via docker to monitor golang applications"
description = "Using docker in order to deploy a elasticsearch, logstash, kibana, metricbeat, filebeat for logging"
tags = [
    "devops",
    "golang",
]
date = "3018-03-14"
categories = [
    "devops",
    "golang",
]
+++

Out there, the ELK (Elasticsearch, Logstash and Kibana) tech stack is a well known combination of technologies that is used for creating centralized logging of applications. Elasticsearch is your "database" in this stack and holds the logging data that is produced by the applications. Logstash is our "processing" layer which processes data that is streamed into it. Logstash can receive data from many sources and after processing the data, it can then dump the data onto elasticsearch which it can then index for further use. Kibana is our vizualization layer that holds the frontend to allow us make use of the data in elasticsearch and have it vizualized into graphs and tables and charts for easier understanding.

In order to make things simpler, we would use docker. This would allow us to run the ELK stack (as well as any other components) without requiring us to install the various language runtimes. We would run the containerized applications as well as components of the ELK stack, Elasticsearch, Logstash and Kibana and see how these components can potentially work together.

Summarizing some of the stuff that would need to be set up:

- Setting up 3 servers with docker swarm
- Setting up sufficient workloads on each of the servers; each of them would call the other
- Configuring and running filebeat on each of the nodes (These would serve to scrape the data from the docker logs)
- Configuring and running logstash which would accept input from the filebeats configured previously
- Configuring elasticsearch to accept input from logstash
- Configuring a dashboard on kibana to view data from elasticsearch
