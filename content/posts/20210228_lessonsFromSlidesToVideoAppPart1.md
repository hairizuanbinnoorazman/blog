+++
title = "Lessons from building Slides to Video App - Part 1"
description = "Lessons from building Slides to Video App. A review on Application structure, devops practises, CI practises"
tags = [
    "golang",
    "slides-to-video",
]
date = "2021-02-28"
categories = [
    "golang",
    "slides-to-video",
]
+++

A long time back, sometime in 2019 (which is almost an eternity ago ), I kind of did up an application that can take some slides saved in a pdf file and generate a video out of it. I kind of talked about it in a lightning session during the following event at Google Devspace https://events.withgoogle.com/la-kopi-serverless/. The input to the application would be the slides in a pdf format as well as some sort of "script". The words in the script would be used to generate the voiceover and then it would be used as part of the video. Essentially, the aim of the app would be create a "presented" version of the slides in a video form without requiring a person to present it. Everything about it is just generated via tools/products available on GCP.

The project is kind of a pet project that I continued working on; 2 years later, the structure of the project is definitely way different compared as to when I first started with the application. I will probably list out the list of changes and provide reasons for why said changes are being made.

Also, this was previously a closed source application. I've cleaned up the repo such that it should be ok as an open source code - but there is still plenty of work that still needs to be done

The link to the repository is here:  
https://github.com/hairizuanbinnoorazman/slides-to-video

# Moving from separate git repos into one repo

When I first started the whole project, the application is split into multiple microservices. It kind of made sense then - the application's main deployment target was Google Cloud Run. For the uninitated, one could say Google Cloud Run is just you (the user) getting Google to run docker containers on your behalf. Pricing is based on utilization of the container - which makes this a very cheap option to build and deploy small personal projects.

The structure of the projects was in 5 git repos. It is organized as follows:

- API (as well as manager)
- PDF Splitter Service (receives tasks as Jobs)
- Generate Short Video Snippets on per slide basis (receives tasks as Jobs)
- Concatenating Short Video Snippets into one final video (receive tasks as Jobs)
- Frontend (Basic Elm frontend)

The 5 microservices are deployed as 5 different services with Pubsub as the central plumbing that connects the "API server" which is like a manager of sorts with the worker services (PDF Splitter, Generate Short Video Snippets and the Concatenating short video snippets services).

However, seeing that initial development of the microservices have always been targetted to be deployed on Google Cloud Run - it makes it really really difficult to test. This is kind of opposite of the promise of utilizing containers where we can have the same container on dev environment and test it locally before deploying it to production.

The problem is not on per microservice level. It is relatively easy to test each microservice individually since each microservice exposes a http endpoint. It is easier to just test that endpoint and check that the required output is produced. Unfortunately, it is close to impossible to test the integration of the 5 microservices locally (due to the reliance on Google Pubsub mechanism to invoke the worker microservices etc). Also, there are bits of hard-coded urls peppered all over the codebase across the 5 microservices making it impossible to have a local environment to test with

After the initial demo during event on Google Devspace, I reflected on this and decided that a local environment is important. It doesn't make sense to keep deploying to Google Cloud Run just to test the functionality of the application. At the same time, I would want to have the application to be deployable to various other environments; including normal Virtual Machine environment as well as Kubernetes environments. This would mean a huge re-architecting of the code base is needed.

Before making any changes, I decided to take a look at code repos out there and how some of them are doing such code structures within their git repositories. Some examples I was referencing from were Loki codebase (Grafana), Jaeger (Jaegertracing). These example opensource code out there were also microservices and it looks like the code for them are all dumped into a single git repository. With this reference, the Slides to Video application that I am building would follow these example code structures.

There are definite benefits from undergoing this change:

- Easier code maintainance. Code is no longer across 5 git repositories but instead accessible from a single git repository. The alternative would be to set up a sixth git repository that would have 5 git submodules to the separate git code repositories
- Easier to set up a docker-compose file that can stitch together all 5 microservices into one single integrated setup
- Less code duplication. Many of the worker services need to interact with same Google Cloud Services (mainly Google Cloud Storage). Previously, the same code to interact with it was copied across the various microservices. Any change needs to be replicated over. An alternative to this setup if the microservices had been in separate git repositories is to set up a "common" golang library which seems like overkill in this scenario
- Easier to setup and ensure that all versions of all microservices for this project is synchronized. There is no need to think too much about version compatability between the microservices

There are possible fallbacks for such a setup though

- Harder to set up CI workflows for each individual microservice. In the case where code is only changed in one of the microservice - how to limit the testing to only that microservice? What if the code changed is shared code that is used across multiple microservices? Or do we just bite the bullet and test all the code each time any code is changed?

# Deciding a frontend technology

There are too many frontend frameworks, tools and languages out there. Each frontend comes with its own benefits and drawbacks. Let's go through the various popular options out there:

- ReactJS
- VueJS
- AngularJS
- Plain HTML + Javascript served from Backend Server
- ELM (I'll admit this ain't too many popular in usual lists)

I generally draw the line for the 3 Javascript frameworks - ReactJS, VueJS and AngularJS. For ReactJS, the framework moves too fast. As a backend engineer, I generally don't follow and keep along with trends of that framework and I have a very strong feeling that even if I coded a decent frontend now, a few months later, it might be "outdated" and I might have to change to keep up with the documents. In the case of VueJS and AngularJS, I wouldn't choose them as well for my personal project, partly due to unfamilarity and also due to the fear that they too move just as quickly as ReactJS. E.g. Angular already hitting it's 12th major version as of the release of this blog post.

Initially, I wanted to just stick to plain html and javascript served from a backend built and compiled using Golang. However, after a short while, working with Javascript serves to be more difficult that expected. The context switch moving between html, javascript and golang makes it pretty hard to handle state as well as to manage the data on frontend. At the same, while coding javascript, I did realize that its pretty difficult to not rely on any framework; there are too many frontend concerns which I would need to manually handle if I happen to not rely on the frameworks. I even tried looking into libraries like Jquery but after comparing the development experience compared to something I tried previously (Elm), I found the experience severely lacking.

This leaves Elm, a language that I tried out previously (and I kind of liked the initial experience of working with it). One the main reasons for liking it is the slow rate of updates to the language - see the Elm version history, each version upgrade are months/years away from each other. Another nice aspect is definitely all the helpful error messages that are thrown the moment something is amiss in the elm codebase. E.g. Wrong types, typos in variables, unused variables, unhandled conditions etc. Such features make it nice to work with elm since I generally won't be working/dealing too much on the frontend for this project. The frontend serves to be a basic UI to interact with the system.

As much as I call out to the various nice features in Elm, there are definitely things to look out for as one works with it. Elm is way less popular as compared to Javascript framework and it shows in Google Search Results. There is less stack overflow articles to help you solve your problems which means that there are times where one would need to tinker around with the code till it work (usually the error messages will help with this; I haven't been stuck for too long while working with it)

# Integration Tests are suddenly very important

One of the changes I thought of implementing in the project is the capability for the project to be deployed on multiple platforms. Some of the targeted platforms to be deployed to for the project would be Kubernetes and Google Cloud Run. In the future, I do want to deploy to platforms on other cloud providers like AWS lambda or even on manually Knative platforms etc.

However, this form of capability requires plenty of qa work to ensure that the functionality of the project is consistent between the different deployments. I definitely can't afford to do that manually - the only way to do it consistently would be to write up a whole suite of integration tests to do a consistent behaviour as the project is deployed to various platforms.

The integration tests are mostly just api calls called via pytest scripts. However, at the moment, I have not set up proper Continuous Integration workflow to test it on the various platforms. There is definitely a need to do up some scripts to build the artifacts as well as to deploy said artifacts to targeted and platform and then to run the pytest scripts. This would definitely take a quite a bit of effort to set up. There are other things to also consider here which is to decide where to run said integration tests (a manual Jenkins setup? Or Google Cloud Build? Or Github Actions?)

I will provide an update on the continuous integration efforts in future blog posts on this project.