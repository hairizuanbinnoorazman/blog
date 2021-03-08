+++
title = "Deploying R Shiny Server to Cloud Run"
description = "Deploying R Shiny Server to Cloud Run. A dashboard tool that remains cheap to deploy and operate"
tags = [
    "google cloud",
]
date = "2021-03-05"
categories = [
    "google cloud",
]
+++

Sometime earlier this year (2021), Google Cloud Run started to support websocket support - which is one of the critical components in order to be able to run a R Shiny Dashboard application. 

Refer to the the following documentation on the Google Cloud Run website:  
https://cloud.google.com/run/docs/release-notes  
https://cloud.google.com/run/docs/triggering/websockets  

Let's see how to quickly get a R Shiny Server application running on Google Cloud Run. But before we get one to run on the Google Cloud Run service, let's try to get one running on our local computer.

If you head over to the following website, we can just quickly run a simple docker image that already has shiny installed in it and test it out on our local computer.

```bash
docker run --rm -p 3838:3838 rocker/shiny:4.0.0
```

If we head over to the local url: http://localhost:3838/sample-apps/hello/. The website displayed should be one that is interactive; it shouldn't be completely grayed out. If grayed out, that would mean that the websocket connection has already expired or broke etc. Unfortunately, seeing that this situation deals with own local computer, it would be something that you have debug manually on your own if any issue arises.

There are other sample functionality available in this image. You can check them out before configuring further:

- http://localhost:3838/01_hello/
- http://localhost:3838/02_text/
- http://localhost:3838/03_reactivity/

You can find and understand more by going into the following folder in the container: `/srv/shiny-server`

# Pushing the rocker/shiny image to Google Container Registry/Artifact Registry

The first step before before we can deploy such a service to Google Cloud Run is to get the image into the project's container/artifact registry we wish to deploy in.

Ensure that our docker cli tool can authenticate to our Google Cloud Project  
https://cloud.google.com/container-registry/docs/advanced-authentication#gcloud-helper

```bash
gcloud auth login
gcloud auth configure-docker
```

With that, we can then push the image to the respective project's container/artifact registry. If we are to push to the container registry (Please substitute the project id accordingly): 

```bash
# Re-tag the public rocker/shiny docker image to point to gcr.io/<project-id> registry
docker tag rocker/shiny:4.0.0 gcr.io/<project-id>/rocker/shiny:4.0.0

# Push image
docker push gcr.io/<project-id>/rocker/shiny:4.0.0
```

Although its also possible to push the images to artifact registry and use the images in said registry to deploy the services on Google Cloud Run, we would not cover it here. On initial look, it looks way to pricey as compared to just relying on Google Container Registry instead.

# Create the Cloud Run Service

To deploy the service, we can use the UI simply and deploy it or we can utilize the following gcloud command

```
gcloud run deploy shiny-dashboard --concurrency=1 --memory=2Gi --platform=managed --region=asia-northeast1 --allow-unauthenticated --port 3838 --image=gcr.io/<project-id>/rocker/shiny:4.0.0
```

We can then test that this works as expected and that this whole setup works as expected for this. Do note that this setup has no authentication which may mean issues if you only mean to restrict this R shiny dashboard to only internal company access.

# Expose dashboards for selected users

If all we wanted to do was just to deploy the dashboard in Google Cloud Run, then we can just stop with the actions mentioned above. However, in many cases, we usually deal with "private" datasets that should only be accessed in internal company settings; it should not be exposed to public.

Do take note that R Shiny library doesn't have anything that deals with authentication. (I'm talking more of the open source edition). I'm pretty sure that if you were to look into the enterprise level Shiny framework, you might be able to find some sort of authentication mechanism.

So in order to do protect our data/dashboards, it would be good to put some sort of proxy in front of the dashboards. We can do that via nginx but the authentication options available that are available out of the box might be a little limited. In cases where we would want to authenticate using Google accounts etc, that option may not be readily via nginx mechanism. We might need some external mechanism to string together with nginx which we can then use it to proxy it on. If we're ok with password based authentication, doing it via nginx might be quite easy, although it would still involve setting nginx in some virtual machine etc.

We can instead look into another mechanism that Google Cloud already provide: IAP (short for Identity Access Proxy). Refer to the following documentation for details on this capability: https://cloud.google.com/iap/docs/concepts-overview

IAP is not directly integrated with Google Cloud Run, but it is already integrated with Google Cloud Load Balancer. And we can have Google Cloud Load Balancer serve traffic with Google Cloud Run as its backend. Refer to the following documentation for details on this capability: https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless

With that we can have IAP for our Shiny dashboard via Google Load Balancer by doing the following:

- Deploy the Google Cloud Run and ensure that it requires no authentication but it is only exposed to private network as well as the load balancer
- Configure a Google Cloud Load Balancer (GCLB) with backends
  - Might require creating serverless network endpoints to point to our aleady setup Google Cloud Run service
  - Ensure that you have a domain to not deal with creating the SSL certificates manually. Alternatively, you can create Self Signed SSL certs but you would need to be kind of familiar with all the commands here. Out of convenience, it would be better to just purchase a domain and toss it to Google to manage the SSL cert etc
  - It takes about 10-15 minutes to wait for a good response from load balancer - it takes a long while to provision it
- At this point, test to make sure that the Shiny Dashboard can be accessed from a browser via the domain pointed to it.
- Add your Google user that you would want to access the Shiny dashboard with the `IAP-secured Web App User` role. Reference: https://cloud.google.com/iap/docs/app-engine-quickstart
