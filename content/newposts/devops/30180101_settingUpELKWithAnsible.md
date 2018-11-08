+++
title = "Setting up ELK stack with ansible to monitor golang applications"
description = "Using ansible in order to deploy a elasticsearch, logstash, kibana, metricbeat, filebeat for logging"
tags = [
    "ansible",
    "devops",
    "golang",
]
date = "3018-03-14"
categories = [
    "ansible",
    "devops",
    "golang",
]
+++

Previouly, I have a blog post on how a containerized version of the ELK stack with other applications can be setup to begin logging of the applications accordingly. However, let's say we are in the scenario where we aren't able to use docker containers (could be company policy or security policies); are there ways to deploy such a stack and its respective components without using docker.

There are some ways to do so, one way is to use ansible to run the required configuration management scripts to modify the state of the machines such that the required applications would run. We would need to use ansible to set up the following components:

- Elasticsearch
- Logstash
- Kibana
- Metribeat
- Filebeat
- Golang APM (Application Performance Metrics)
