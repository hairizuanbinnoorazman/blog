+++
title = "Access Cloud SQL from Google Kubernetes Cluster without Cloud SQL Proxy"
description = "Access Cloud SQL from Google Kubernetes Cluster without Cloud SQL Proxy"
tags = [
    "google-cloud",
    "golang",
    "docker",
    "kubernetes",
]
date = "2023-09-13"
categories = [
    "google-cloud",
    "golang",
    "docker",
    "kubernetes",
]
+++

## Introduction

Similar to my previous blog post, we would usually be connecting Google Kubernetes Engine (GKE) clusters to Cloud SQL databases by using the Cloud SQL Proxy. However, we can now use  Private Service Connect, which allows for private communication between different Google Cloud services, similar to how we did for connecting our application in Google Compute Engine (VM) to a Cloud SQL instance.

## Checking for connectivity

Similar to how we can we did it for the previous post where we check if we can connect to the Cloud SQL instance from our Google Compute Engine instance - we can do the same for our application in Google Kubernetes Engine. However, this would first involve starting some small application which we can then install some stuff in order to install the tools that we need to test the connectivity to the Cloud SQL database.

First, let's create a `nginx` container and have it running in our cluster. I'll assume that you would be familiar to connect to a Kubernetes cluster provisioned in Google Cloud.

```bash
kubectl create deployment lol --image=nginx
```

Once we have it up and running it, we can go into the image via the following commands:

```bash
kubectl get pods

kubectl exec -it <pod-name> -- /bin/bash
```

Getting the pod name is done by choosing it from the `kubectl get pods` command. Next, we would install nmap tool. (Do note that we can't ping our Cloud SQL instance)

```bash
apt update && apt install -y nmap
```

We can then run the `nmap` command against our private IP address provided after provisioning our Cloud SQL instance.

```bash
$ nmap -Pn x.x.x.x
Starting Nmap 7.93 ( https://nmap.org ) at 2024-01-21 12:03 UTC
Nmap scan report for x.x.x.x
Host is up (0.0016s latency).
Not shown: 999 filtered tcp ports (no-response)
PORT     STATE SERVICE
3306/tcp open  mysql

Nmap done: 1 IP address (1 host up) scanned in 4.28 seconds
```

From the above, it seems that we can connect to the database just fine from a pod within the cluster.

## Deploy a helm chart

The next step would be to deploy a helm chart that would make use of our database. Refer to the following application built here (similar to the previous [blog post](/access-cloud-sql-from-google-compute-engine-without-cloud-sql-proxy/)). Refer to the following url: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicMigrate

We can run the following commands to build the docker image:

```bash
docker build -t gcr.io/xxx/basic-migrate:v1 .
docker push gcr.io/xxx/basic-migrate:v1
```

We would need to create the following custom yaml which we can use to feed to our helm chart. This values would tweak values for our helm chart that would be installed to our cluster. Do take note of the important value to be changed which is the `appConfig.databaseHost` value.

```yaml
image:
  repository: gcr.io/xxx/basic-migrate
  tag: "v1"

resources:
  limits:
    cpu: 500m
    memory: 500Mi
  requests:
    cpu: 250m
    memory: 256Mi

appConfig:
  databaseHost: x.x.x.x
```

We will run the helm chart installation with the above yaml configuration.

```bash
helm install -f app-values.yaml basic ./basicMigrate
```

After waiting a while, we can should see it successfully installed on our cluster.

```bash
$ kubectl get pods
NAME                                  READY   STATUS      RESTARTS   AGE
basic-basic-migrate-c478fd699-mbctt   1/1     Running     0          13s
basic-basic-migrate-migrate-49hw8     0/1     Completed   0          19s
lol-69f74bb-x5pkj                     1/1     Running     0          19m
```

## Checking that it actually works

We would still want to double check that the whole setup above works. We can do so by still making use of our `lol` deployment that uses the `nginx` docker image. First we would install the `mariadb-client` deb package.

```bash
apt install -y mariadb-client
```

Next, we can run the following command:

```bash
mysql -h x.x.x.x -u root -p
```

It will prompt you for a password. Once the right password is passed, we would be able to start manipulate the database with root credentials. Next, we would run the following SQL commands.

```bash
> use application;
> show tables;
+-----------------------+
| Tables_in_application |
+-----------------------+
| schema_migrations     |
| users                 |
+-----------------------+
2 rows in set (0.002 sec)

```

The important part here is that the `users` table exists - that would implicitly indicate the migration is run successfully - naturally, we can do further tests - but this should be sufficient for now.