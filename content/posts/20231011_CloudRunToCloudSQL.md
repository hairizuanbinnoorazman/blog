+++
title = "Access Cloud SQL from Google Cloud Run without Serverless VPC Access Connectors but via VPC"
description = "Access Cloud SQL from Google Cloud Run without Serverless VPC Access Connectors but via VPC"
tags = [
    "google-cloud",
    "golang",
    "docker",
]
date = "2023-10-11"
categories = [
    "google-cloud",
    "golang",
    "docker",
]
+++

## Introduction

Previously, Serverless VPC Access connector is a commonly used solution to connect Cloud Run to Cloud SQL securely. This option is still available for use today but with all the previous blog posts that cover how we can:

- [Connect from Cloud Run to VPC](/accessing-google-compute-instances-via-cloud-run/)
- [Connect instance from VPC to Cloud SQL](/access-cloud-sql-from-google-compute-engine-without-cloud-sql-proxy/)

It is only a simple manner where we can extend this and also say that we can connect our Cloud Run deployment to a cloud SQL without needing to setup a Serverless VPC Access Connector. However, there are a few pre-requisites that needs to be done in order for this to work.

- Have our Cloud SQL be joined to our VPC of choice. Cloud SQL is usually deployed in a separate network of sorts - so involves setting up a [Private Service Access](https://cloud.google.com/vpc/docs/private-services-access) - the underlying implemnentation is one where the "external" instance (which is Cloud SQL here) would be provided an internal IP address from our VPC - of course this doesn't go into detail - you can check [VPC Network Peering](https://cloud.google.com/vpc/docs/vpc-peering) for more details on such detailed networking information.
- Have our Cloud Run also link up to the VPC as well

## Deploying the migration app

The same application that was used for the previous blog posts can be used here. Do take note that we are not running the migration job here - we need to rely on another mechanism to do the migration before our application can begin running (probably will be covered in another blog post of how this could be done in a sane way)

Let's say the database schema has already been set up; all we need to do is simply to run the migration. How shall we do this?

First part is the same - build our docker image and have that available in Google Container Registry/Artifact Registry. We can do so with the following commands (tweak it if need to push to artifact registry - it uses different domains)

```bash
docker build -t gcr.io/xxx/basic-migrate:v1 .
docker push gcr.io/xxx/basic-migrate:v1
```

Once the container is available on Cloud SQL, next step is to ensure that our Cloud SQL is already set up with our VPC - this will not be covered in this blog post. Do refer to previous blog posts (refer to the links for it at the top) on how this was done.

Next step is to simply setup our Cloud Run and have it connect to our Cloud SQL instance. There are a few things to take note though:

- The need to setup the various environment variables. There is no proper defaults if its not set. For more sensitive vars - we can probably also see if we can use Google Cloud's Secret Manager but that is a story for another day.
  - `DATABASE_HOST`
  - `DATABASE_NAME`
  - `DATABASE_USER`
  - `DATABASE_PASSWORD`
- Another thing to take note is the default command being used to run the service. The `basic-migrate` app is a simple binary but it has a couple of subcommands. The docker image being build does not set the proper `app server` as the default command to be run - this has to be passed to Cloud Run to properly start it
- The application is actually exposed on port `8888` instead of usually `8080`
- Health checks need to be configured properly - a simple "TCP" check is insufficient - there is a reason why we have a `/healthz` endpoint - its for our healthcheck across various deployments like in a VM or in GKE as well. It applies to Google Cloud Run as well it seems.

With that, we now have a Cloud Run to connects directly to a Cloud SQL database. It's somewhat disappointing that we almost have an entirely serverless stack with this setup but it's definitely better than having a Cloud SQL instance as well as a VM instance and having that setup - it would be priced way better. (This is for smaller projects only - larger projects actually benefit from having it deployed to a proper VM or even in GKE)