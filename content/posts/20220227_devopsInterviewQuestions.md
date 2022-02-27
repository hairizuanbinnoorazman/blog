+++
title = "Devops Interview Questions"
description = "Devops Interview Questions"
tags = [
    "devops",
    "kubernetes",
    "docker",
]
date = "2022-02-27"
categories = [
    "devops",
    "kubernetes",
    "docker",
]
+++

This is a list of notes for possible interview questions with regards to devops roles. Interview questions for devops are particularly hard to cover since devops roles generally cover a broad range of topics and technologies. I will update this page as I see any interesting or "hard" questions to cover.

Weirdly enough, a lot of the questions gather are usually "fringe" edge cases that one may accidentally come across due to unique use cases. 

I will update this post as time goes by - if there is more information on this

- [Docker](#docker)
  - [What's the difference between COPY and ADD?](#whats-the-difference-between-copy-and-add)
  - [How is isolation achieved in Docker?](#how-is-isolation-achieved-in-docker)
  - [How does volume mounting work in Docker?](#how-does-volume-mounting-work-in-docker)
  - [Assume you have an application that requires MySQL database. Assume that the app and database is deployed in 2 separated containers. Why can't the application use "localhost:3306" to connect to the database?](#assume-you-have-an-application-that-requires-mysql-database-assume-that-the-app-and-database-is-deployed-in-2-separated-containers-why-cant-the-application-use-localhost3306-to-connect-to-the-database)
- [Kubernetes](#kubernetes)
  - [What is the architecture of Kubernetes?](#what-is-the-architecture-of-kubernetes)
  - [What are some of the ways to expose application endpoints within k8s externally?](#what-are-some-of-the-ways-to-expose-application-endpoints-within-k8s-externally)
  - [What's the difference between statefulsets and deployments? And how does statefulsets allow databases to be deployed safely into Kubernetes?](#whats-the-difference-between-statefulsets-and-deployments-and-how-does-statefulsets-allow-databases-to-be-deployed-safely-into-kubernetes)
  - [How does a external network request reach into a pod via Ingress?](#how-does-a-external-network-request-reach-into-a-pod-via-ingress)
  - [How is volume mounting handled in Kubernetes?](#how-is-volume-mounting-handled-in-kubernetes)
  - [What is a headless service?](#what-is-a-headless-service)
  - [When creating operator - how are reconcilition loops started?](#when-creating-operator---how-are-reconcilition-loops-started)


{{< ads_header >}}

## Docker

### What's the difference between COPY and ADD?

- ADD was probably introduced earlier - ADD can add files from local filesystem into container. It can also pull from remote sources into container. It can also auto extract files from tar files into docker image
- COPY can only do local filesystem into container
- COPY is the more "secure" solution here of sorts

### How is isolation achieved in Docker?

Coming

### How does volume mounting work in Docker?

Docker CLI will communicate with Docker local "server" daemon, reference: https://github.com/docker/cli/blob/cf8c4bab6477ef62122bda875f80d8472005010d/vendor/github.com/docker/docker/client/container_create.go#L54

- From docker-cli repo (a "post" request call to create container) -> moby/moby repo
- daemon pkg -> createContainer call which then calls specific os specific settings.
- daemon pkg -> createContainerOSSpecificSettings
- volume/service pkg -> Ask volume service to create -> Ask volume store to create -> Ask volume driver to create -> (Default Mac docker volume plugin uses local -> Creates directory and sets permission)
- container pkg -> AddMountPointWithVolume (just object representation)
- daemon pkg -> populateVolumes
- Calls Volume mounts from moby/sys repo
- Final unix mount command: https://github.com/moby/sys/blob/main/mount/mounter_linux.go#L30

### Assume you have an application that requires MySQL database. Assume that the app and database is deployed in 2 separated containers. Why can't the application use "localhost:3306" to connect to the database?

Coming


{{< ads_header >}}

## Kubernetes

### What is the architecture of Kubernetes?

Consists of the following components:

Control plane components

- etcd (store state of k8s)
- api-server (expose k8s api)
- kube-controller-manager (has multiple controller for various k8s assets e.g. jobs, endpoints etc)
- kube-scheduler (handles scheduling of pods taking into account of taints, annotations, constraints, affinities)
- cloud-controller-manager (manager that would communicate with the hosting provider)

Node components

- kubelet (agent that make sure pod is running on node)
- kube-proxy (pod that maintains network rules)
- container runtime

Reference: https://kubernetes.io/docs/concepts/overview/components/


### What are some of the ways to expose application endpoints within k8s externally?

- Ingress
  - Depends on how the Kubernetes cluster is setup and its cloud environment
  - In Google Kubernetes Engine, a load balancer is actually created and routes are created onto it. The routes that reflect back into the cluster; providing a single external IP address that routes based on the ingresses defined.
- Nodeports
  - Specified within Kubernetes Service objects
  - Maps the ports exposed from the container to port on host machine on reserved ports of 30000-32768
- Load Balancer
  - Specified within Kubernetes Service objects
  - In a cloud based environment, there will be a controller monitoring the service objects being created that requests for load balancers. It will communicate with its own respective clouds to create a load balancer and attach the external load balancer to that service.


### What's the difference between statefulsets and deployments? And how does statefulsets allow databases to be deployed safely into Kubernetes?

Coming

### How does a external network request reach into a pod via Ingress?

Coming

### How is volume mounting handled in Kubernetes?

Coming

### What is a headless service?

Coming

### When creating operator - how are reconcilition loops started?

Within the `xxxxx_controller.go` file (based on kube-builder framework), it would usually contain some code to build up the controller manager object. The object build up with various properties (builder pattern) but the most important one would be `For(...)` - that would identify kind of object that controller is managed. The `Complete` method would invoke various controller functionality; the kubernetes "watch" functionality is invoked. 

Reference: https://github.com/kubernetes-sigs/controller-runtime/blob/master/pkg/builder/controller.go#L81 (May not be accurate)

Reference for watch documentation: https://kubernetes.io/docs/reference/using-api/api-concepts/#efficient-detection-of-changes

Possible youtube video on details of this: https://www.youtube.com/watch?v=PLSDvFjR9HY