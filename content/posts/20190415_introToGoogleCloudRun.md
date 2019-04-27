+++
title = "Introduction to Google Cloud Run"
description = "Serverless solution by deploying Docker containers on Google Cloud Platform"
tags = [
    "google-cloud",
    "serverless",
    "r",
]
date = "2019-04-15"
categories = [
    "google-cloud",
    "serverless",
    "r",
]
+++

There are various serverless compute solutions on the Google Cloud Platfrom; initially it used to be only Appengine and Google Cloud Function. Google Appengine is a solution that allow you to focus on writing up apps and allow Google to take of deployment/scaling/operations. Google Cloud Functions take a step further and allow you as a developer to develop just plain old functions and allow Google to handle the rest of it, thereby making it easier to split your app functionality to parts that require to scale and parts that don't need to.

Each of the above have their advantages and disadvantages. Advantages was ease of use and get started with an app deployed to production really really quickly. However, for both products, they introduce platform lock-in as well as the need for users to wait for platform support. The products are only released for few languages (they get updated as time goes on). Let's take Google Cloud Functions; at the moment of writing, one can can use `node.js`, `golang` and `python`. `Java` support should be coming in soon. But these are the only assortment of languages available. If you use something exotic something like erlang or R or even C++.

During Google Cloud Next 2019, Google announced a release of Google Cloud Run which essentially is a product that allows you to write http based products in Docker containers. These docker containers can be passed to Google which they manage and run it. The containers can deployed from 0 instances to 1000 instances with memory requirements of the containers being settings that you can optionally set to handle application requirements.

## Deploying a R API to Google Cloud Run

In order to demonstrate this, we can try to create a http application that is based using R. R has a library that can handle http based workloads called plumber. With it, you can build a web based application that can receive `GET` and `POST` requests which can then be further handled within the application.

The below code is for `app.R` which describes the main R application that would handle the logic of a web based R application

```R
#* Echo back the input
#* @param msg The message to echo
#* @get /echo
function(msg=""){
  list(msg = paste0("The message is: '", msg, "'"))
}

#* Plot a histogram
#* @png
#* @get /plot
function(){
  rand <- rnorm(100)
  hist(rand)
}

#* Return the sum of two numbers
#* @param a The first number to add
#* @param b The second number to add
#* @post /sum
function(a, b){
  as.numeric(a) + as.numeric(b)
}
```

A R file to handle dependency management in `dep.R`

```R
install.packages("plumber")
```

A R file to handle starting the R application in `start.R`

```R
library(plumber)
r <- plumb("app.R")
r$run(port=8080, host="0.0.0.0")
```

A Dockerfile to package the R API into a docker container

```Dockerfile
FROM r-base
ADD dep.R .
RUN Rscript dep.R
ADD app.R start.R ./
EXPOSE 8080
CMD Rscript start.R
```

With all that, we can then run the following commands:

```bash
docker build -t gcr.io/{google-project-name}/R-Api:0.0.1 .
docker push gcr.io/{google-project-name}/R-Api:0.0.1
```

Google Cloud Run currently seems to only be able to deploy from the `Google Cloud Registry` at the moment, so we would need to use that for now.

We can deploy the Google Cloud Run service to run with this:

```bash
gcloud beta run deploy R-Api
  --allow-unauthenticated
  --concurrency=1
  --image=gcr.io/{google-project-name}/R-Api:0.0.1
  --memory=512Mi
```

A few comments before continuing:

- R is a single threaded language. When we build http applications with the Plumber R library, it shouldn't be able to handle parallel web requests coming in at the same time. Another process manager/application is actually needed to handle this. However, to reduce complexity, we can deploy the R application with concurrency as 1 - this would mean each container can only handle 1 application at any point in time.
- Cloud Run, similar to Google Cloud Function do face the cold start issue. If the container is big and if the application take a while to start, then the initial application latency will be higher

With that, we have deployed an application onto Google Cloud Run. Some issues you could face would probably be enabling the APIs for the above services to even begin using but that should be relatively easily resolved.

Below are some references on this:

- R-API codebase: https://github.com/hairizuanbinnoorazman/api-with-R
- Creating Async workloads on Google Pubsub: https://cloud.google.com/run/docs/tutorials/pubsub
- Some slides on some points to highlight when deploying R-API docker container to Google Cloud Run: https://docs.google.com/presentation/d/1M8EhARDBY33IefEz356NhdUkkSyUZo1tHZBkMt-NtpE
