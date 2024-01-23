+++
title = "Serverless Applications with Cloud Run with Serverless MySQL from PlanetScale"
description = "Serverless Applications with Cloud Run with Serverless MySQL from PlanetScale"
tags = [
    "google-cloud",
    "golang",
    "docker",
    "serverless",
]
date = "2023-09-27"
categories = [
    "google-cloud",
    "golang",
    "docker",
    "serverless",
]
+++

Serverless computing, as seen in platforms like Cloud Run or AWS Lambda, allows developers to run code without managing the underlying infrastructure. This is achieved by automatically scaling the resources based on the incoming requests, and users are billed based on the actual execution time and resources consumed during each function or container invocation.

When it comes to databases, managed database services exist, but they often involve a more traditional pricing model based on allocated resources, storage, and sometimes a provisioned throughput. These databases might offer automation for certain tasks like backups, updates, and scaling, but they do not strictly follow the same "pay only for what you use" model as serverless compute services.

The challenge with creating a fully serverless database that aligns with the pricing model of serverless compute services lies in the nature of databases. Databases often require persistent storage, continuous availability, and consistent performance, which makes it challenging to implement a pure pay-as-you-go model.

One of the services that fits the billing model the closest as compared to services such as Cloud Run would be the database provided by Planetscale. Planetscale provides mysql databases (or mysql-like databases) that is bills its users based on read and write requests done on the database as well as the amount of data stored on the database. We can compare this to the usual billing approaches by services such as Cloud SQL that charges its users based on the amount of time a Cloud SQL instance is kept running.

The usual billing approach might probably be cheaper at larger scales but for smaller projects that still require a MySQL database - it does seem quite unreasonable to pay for a small server instance that needs to be kept alive even though the amount of data requests is pretty small. The alternative approach here would be switch over to alternative databases that has that model - in Google Cloud, we would still have Cloud Datastore that bills user on data being stored - but its a completely different database - we would have to alter a huge chunk of code in order to be able to access and manipulate the data on it.

## Creating database on planet scale

It is pretty straightforward to create a database on planetscale - the product set is pretty small - most of the choices made available to the user pertains to the size of the database that is going to be requested. Naturally, with a small project - we would definitely request for a small database.

During the provisioning step - we would be given a generated username and password which would then use to connect to the database. After the provisioning of the database, we would somehow end up in the following page that would show overall details of the database that we provision.

![planetscale-db](/20230927_cloudRunAndPlanetScale/planetscale-db.png)

Even if we missed out the important details of attempting to connect to the database, we can simply click on the "Connect" button and that would reveal the various methods to connect to the database - even via language or the various cli such as planetscale's own cli tool.

## Connecting to database via sample application

Naturally, a good thing to do to check if an approach is viable is to have a sample application that would connect to the database. We can reuse the following application in order to attempt to connect our serverless application deployed on Cloud Run to connect to the newly provisioned database on Planetscale (that is also billed in a serverless-ish manner). https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicMigrate

I'll be skipping on possible approaches on how to run a database migration but instead, focus on how to get the application running and specific important things to take into account when trying to do so. 

- Planetscale only allows us to connect to it via tls connection it seems. Hence, our connection string has to contain the parameters `useTLS=true` in order for us to handle that. However, if we have that permanently, that will make local development a pretty painful process - we can't be also attempting to set up TLS certs for our own local mysql instance for testing - that'll be too much overhead just to test a certain functionality. This is why we would simply a condition that would add the TLS settings, assuming we pass that variable via environment variables.
- Health checks are done on the `/health` endpoint
- Database is external - so we don't need to tinker around with sql proxies or even connect it to vpc - refer to previous posts on how to connect Cloud Run to Cloud SQL - that'll save on administrative effort to do so.

Do note that Cloud Run has issues to support endpoints that end with `z` - hence a recent change to remove that (check the history of the `main.go` file if you're curious)