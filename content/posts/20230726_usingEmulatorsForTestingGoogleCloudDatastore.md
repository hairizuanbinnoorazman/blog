+++
title = "Using Emulators for testing Google Cloud Datastore integration"
description = "Using Emulators for testing Google Cloud Datastore integration"
tags = [
    "golang",
    "docker",
    "google-cloud",

]
date = "2023-07-26"
categories = [
    "golang",
    "docker",
    "google-cloud",
]
+++

## Motivation for finding emulator for Google Cloud Datastore

Many applications out there in the real world would require the use of databases to persist data. In the cases where an application depends on databases such as mysql or mariadb or postresql, we can create some form of "staging" server where we can test that the application works as expected. Additionally, we can even test to make sure that any database migration works as well without too much issues - we can import in some of the data from production and import it into the staging environment to make sure that it works.

With docker, this process is made so much easier. Us developers no longer need to think of how to setup the databases in our machines and "pollute" our machines with various installations of MySQL, MariaDB or any other databases that our applications use. We can simply just pull in the right version of databases, run it and simply test our code. 

This whole setup works in the case where we rely on databases which is not exactly tied to a cloud vendor. However, what if we relied on something like Google Cloud Datastore? There isn't exactly a docker image out there that focuses on having Google Cloud Datastore and exposing said interface for application to test against it. We would need to test the entire flow - including our integration of our codebase with the google-cloud libraries that are imported in our codebase. We can't simply switch to a "fake" version as that wouldn't test our end to end integration to the Google Cloud Datastore database.

Luckily, the `gcloud` command has emulator tooling built it - so we can technically setup a Google Cloud Datastore that integrates well with the official Google Cloud Datastore libraries.

Refer to the following link for the full source code: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicUsingDatastore

The example below is presented with Golang code.

## Running Google Cloud Datastore Emulator

The important bit to running the Cloud Datastore emulator is to get the docker image running. We can do so by running the following command:

```bash
docker run -p 8081:8081 google/cloud-sdk:437.0.1 gcloud beta emulators datastore start --project=test --host-port=0.0.0.0:8081
```

Note that it is exposted on port 8081. We would also need to inform the emulator on how it is to be exposed/binded - which in our case, we need to ask it be binded to 0.0.0.0. This is done so that it can accept traffic from anywhere.

The next important bit would be to feed certain environment variables that will be using by the official Google Cloud Golang libraries - `DATASTORE_PROJECT_ID` and `DATASTORE_EMULATOR_HOST`. Emulator host will be the one that will officially tell the Golang library that calls datastore golang code to use and connect to emulator. If this is not done - it will always be trying to connect to the official Google Cloud Datastore product over the internet.

```bash
DATASTORE_PROJECT_ID=test DATASTORE_EMULATOR_HOST=localhost:8081 go run main.go
```

The rest of the code is somewhat similar to how would code when it comes to adding, deleting and listing of resources from a database (which in our case is the Google Cloud Datastore)

## Further Thoughts

With this, we can replicate a mechanism that some people have been using to do automatic integration testing. We can test our code against an actual database - https://testcontainers.com/. With this library, we can programmatically create the cloud datastore and run it and then we can run the test to check our code is integrated properly against the cloud datastore. That would be "lighter" in nature as compared to testing it against an actual Cloud Datastore in Google Cloud Platform project. If we are to use the actual Google Cloud Datastore - we would need to think of cleaning up the database after our integration tests are doen - that would definitely add a huge amount of "pain" to our work.