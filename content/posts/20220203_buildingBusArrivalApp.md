+++
title = "Bus Arrival App - Singapore"
description = "Bus Arrival App - for Singapore buses - built using Golang, hosted on Google Cloud Run, frontend built with Elm"
tags = [
    "personal",
    "golang",
    "google-cloud",
    "elm",
    "nginx",
]
date = "2022-02-03"
categories = [
    "personal",
    "golang",
    "google-cloud",
    "elm",
    "nginx",
]
+++

This is a quick sample tool to retrieve bus arrivals in Singapore. In order to use it, we would need to find for the Bus Stop ID or Bus Stop Code from where we're taking the bus from. After keying it, it would fetch the records from LTA Datamall's real time bus arrival API and present those records in this tool.

The Bus Stop IDs/Codes that you've keyed in here will be stored within the browser via "localstorage" - a refresh will wipe all the bus arrival times (We would would want more updated records). However, a refresh button is available on per bus stop to refetch and repopulate the records. See the tool below here.

{{< bus_arrival >}}

If you're testing the following tool in "out of bus services" hours, you can try using Bus Stop IDs `99999`, `99998` and `99997`. They are sample, "fake" bus stops and I'm not aware if such bus stops are actually real.

The tool may have some bugs but considering that it's built over a weekend; once I have a bit more time to spare, I'll consider fixing up the bugs and improving the look in the following weeks.

{{< ads_header >}}

## Building the Bus Arrival tool - Overview

There are multiple parts to the building of the Bus Arrival tool; we would first need to build a backend. The backend would serve to retrieve the records from lta datamall and is done to somewhat protect the lta datamall secrets that we are using to retrieve the records. Out of familiarity, I'm building it using Golang as I'm most familiar with it and it's considered the easiest for me to maintain as there is static typing in place. I'll explain more about it in the next section.

Since we're embedding the frontend into this blog post, we can rely on Elm (as there are already processes/code in place to make this happen more easily). I'll probably be a heavy user of the tool so I'll want certain features such as making sure that bus stop IDs are saved to ensure that I don't need to keep looking up on the bus stops IDs that are generally frequent to.

## Building the backend of Bus Arrival tool - Golang backend

You can reference the Golang code being referenced here in the following link:  
https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/bus-arrival

The following Bus Arrival embedded web application is built using Golang. The first thing to immediately consider when building the backend is to figure how to access the LTA datamall APIs. There is a guide to its usage here: https://datamall.lta.gov.sg/content/dam/datamall/datasets/LTA_DataMall_API_User_Guide.pdf

In order to get the account key, we would need to signup and request for an account key from LTA Datamall

We can probably quickly that the API works it with curl:

```bash
curl -H 'AccountKey: XXXX' http://datamall2.mytransport.sg/ltaodataservice/BusArrivalv2?BusStopCode=83139
```

Do make sure that the service is not undergoing any downtime while testing this. But then again, most of the time, the downtime should only happen in the middle of the night.

In order to access the LTA Datamall APIs via Golang, we would need to create the required structs in order to parse the responses return from the LTA Datamall endpoint. Either that, or rely on a Golang library that just happens to do that heavy lifting. Refer to the following Golang library that provides that functionality: https://github.com/yi-jiayu/datamall

The rest of the concerns for the service is somewhat settled; the main important bit is just accessing, parsing and simplifying the responses that are returned from the Bus Arrival endpoint of the LTA Datamall APIs. The API is built with Gorilla Golang library which provide an easy way to do routing for such REST APi services. We would also provide some sort of "healthz" behind the `/api/..` route so that it would easy to test and check for frontend code. (To check for accessibility of the route)

Do take note of the fact that the Golang code here DOES NOT have any CORS configured for it. I will expand a bit on that point in the next section on the frontend building of this Bus Arrival tool.

Another interesting point is how the api is structured. We are now using `/api/lta-datamall/v1/bus-arrival` although generally, I like to use `/api/v1/bus-arrival` - the version right after api since apis should have versioning for our sanity. Reason for this is that I need to proxy it during deployment and it'll be kind of hard to proxy just based on the latter api convention. With the lta-datamall, I'm kind of proxying based on "service" rather than just based on "service endpoint" - not sure how to kind of explain it here...

## Building the frontend of Bus Arrival tool - Elm

I really hate tinkering around with CORS. There are too many weird quirks that I kind of need to know. And the thing is, I generally don't handle frontend most of the time. During the first time encountering it, I took so many hours trying to debug it - the behaviour is different across different web browsers, and across different versions of the said web browsers. You can probably read further on this in another post. [CORS with Golang Microservices and Elm Frontend is difficult](/cors-with-golang-microservices-and-elm-frontend-is-difficult/)

As mentioned in the above blog post previously, I've decided to go with the approach of avoiding CORS if I can somehow to do so. As per the previous blog post, I'm going with the approach where my Golang backend is exposed on a docker image on port `8880` while my Elm frontend is exposed on port `8000`. The two services are proxied via nginx installed on my workstation via port `8080`. Because it is from the same domain and same port - CORS restrictions doesn't kick in, so I don't need to handle CORS issues.

The only thing that is different would be the portion that nginx doesn't automatically handle query arguments when doing proxy pass. We would need to construct the full url including the query arguments by adding `$is_args$args`:

```
...
        location ~ ^/api/(.*) {
            proxy_pass http://localhost:8880/api/$1$is_args$args;
        }
...
```

Without that, query arguments will be silently dropped - and that's definitely an issue here.

We can then access and test the frontend by accessing from port 8080 - which is the port that nginx is using. The frontend will call backend using port 8080 which would forward said request to port 8880 accordingly.

## Deploying the application

Backend will be deployed to Google Cloud Run and we would using Google Cloud Secrets Manager. The procedure was done manually (no Google Cloud Build was used here). Image that is used to run the app on Google Cloud Run will be stored on Google Container Registry. In case the names of those products are a bit to vague for you:

- Google Cloud Run: One of Google Cloud Platform's serverless platform. TLDR - docker as a service. Build an image, push it to a container registry and then tell this product to run that image for you. It comes with plenty of limitations but it should be sufficient for quite a fair bit of use cases (since most use cases are just simple CRUD applications)
- Google Secrets Manager: As the name implies, it is just a UI tool to manage secrets that you would inject into servers/containers on Google Cloud Platform. In order for the running servers and containers to access the secrets, the service account in charge of said server/running container needs to be configured to be able to access the said secret.
- Google Cloud Build: One of Google Cloud Platform's CI/CD tools. (The number of such tools are increasing every year - recently - as of the date of writing, there is Google Cloud Deploy as well, which has a different focus). The Google Cloud Build tool is essentially like "jenkins" but more restricted and focused by using docker images to build the necessary artifacts and deploy said artifacts to production.
- Google Container Registry: As the name implies, it is a registry that stores container images. There is another product: Google Artifact Registry which is more "generalized but its unfortunately, way more expensive.

The first part before deploying would be to build the image that we would run for this Bus Arrival app:

```bash
docker build -t gcr.io/<project id>/bus-arrival:v1 .
```

After which, we can push it to Google Cloud Container Registry:

```bash
docker push gcr.io/<project id>/bus-arrival:v1
```

The next parts are kind of UI based which is to:

- Register the LTA Datamall secret into Google Secrets Manager
- Create a new Google Cloud Run service and select the newly pushed image
- Ensure that the number of concurrent images running is low (we don't expect large number of requests for this)
- Add the secret that is to be used in the app (it should be under secrets tab) and choose the right version of the secret from Secrets Manager that should be used.
- Ensure right amount of CPU/Memory is used - which, in our current case, should also be quite low.
- Deploy and run the service

We can check that the application work by pinging the healthz endpoint:

```bash
curl <cloud run endpoint>/api/lta-datamall/v1/healthz
```

That endpoint is there to check that endpoint is accessible.

The next part is the critical bit - remember the bit that the backend doesn't support CORS? This would come back here. We need configure the backend such the backend point exists on the SAME endpoint as the frontend point. Which in our case is the `hairizuan.com`. How should we do this? Do we do it via Nginx?

A bit of context, this blog post is deployed on Netlify - so we can't exactly use nginx since the domain itself is managed by Netlify. Unless I move away from this, then, the Nginx (similar to how to test this whole tool locally) can then be used. Luckily, Netlify has the following - a proxy: https://docs.netlify.com/routing/redirects/rewrites-proxies/

To make it work, we need to add the following to the netlify.toml of the current repo:

```toml
[[redirects]]
  from = "/api/lta-datamall/*"
  to = "https://<cloud run endpoint>/api/lta-datamall/:splat"
  force = false
  status = 200
```

The important part here is the `status` field - it should not be `301`. If 301 - frontend will experience CORS issue once more since the frontend is trying to retrieve resources from another domain.

## Conclusion

This is a pretty fun project; but it's also a project that I was pondering around for quite a while. This kind of came up from the fact that I do want to check bus arrival times but I'm too lazy/cautious to download any application to do this (I've tried one or two apps for this before but it was so buggy and doesn't fit my small little requirement - too many buttons/fields to pass in just to get the information). 

As a final touch, I would create a shortcut for this on my phone and now, it becomes somewhat "app-like"; a small tool that I can quickly access to get the information that I need.

