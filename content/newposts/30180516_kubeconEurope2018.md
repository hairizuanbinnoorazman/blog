+++
title = "Lessons from Kubecon/CloudNativeCon 2018 Europe"
description = ""
tags = [
    "conference",
    "golang",
]
date = "3018-05-16"
categories = [
    "conference",
    "golang",
]
+++

The following set of summaries are from the Kubecon and Cloud Native Con Europe in Denmark from 2-4 May 2018. 

These summaries are from conference talks that I thought provided more interesting thinking points.

The videos for the conference can be found here:  
https://www.youtube.com/watch?v=OUYTNywPk-s&list=PLj6h78yzYM2N8GdbjmhVU65KYm_68qBmo  

Below are some of the talks that I found quite interesting (just my own preference)  
I took some of my personal notes so that I don't need to rewatch the videos once more just to get the main point the video seem to talk about.

## Anatomy of a Production Kubernetes Outage

- Video Link: https://www.youtube.com/watch?v=OUYTNywPk-s
- Production Outage occured
- Blog Post: https://community.monzo.com/t/resolved-current-account-payments-may-fail-major-outage-27-10-2017/26296/95?u=alexs
- Another blog post: https://community.monzo.com/t/anatomy-of-a-production-kubernetes-outage-presentation/37331
- In summary: Checking for compatability between platform, tools are vital - such checks are vital especially on the platform level when they can cause cascading failures across the applications.
- Fallbacks when systems fail is helpful; in the case above, applications failed but transactions continue running.

## Cloud Native Landscape Intro 

- Video Link: https://www.youtube.com/watch?v=_CFgSksTT54
- Introduction to the cloud native landscape tools and github page
- Github Link: https://github.com/cncf/landscape
- Website Link: https://landscape.cncf.io/
- Get the pdf versions of the landscape from Github

## Accelerating Kubernetes Native Applications

- Video Link: https://www.youtube.com/watch?v=8iQRJXJHiZ8
- Operators is a concept that was build on Kubernetes providing the Custom Resource Definitions
- Allows for specific application management; e.g. Managing the running of a database - if a database need to be resized, operators could be programmed to trigger snapshot before switching to a bigger pod which the data can be replicated in. (example only)
- Reasons on why operators are kind of game changing: https://dzone.com/articles/why-kubernetes-operators-are-a-game-changer
- Additional links: https://medium.com/@mtreacher/writing-a-kubernetes-operator-a9b86f19bfb9
- Operator Framework by core os: https://coreos.com/operators/
- Github link to operators: https://github.com/operator-framework/operator-sdk

## Kubernetes Project Update

- Video Link: https://www.youtube.com/watch?v=2eAOx8E6-5Q
- Security
    - Network Policy
    - Encrypted Secrets
    - RBAC
    - TLS Cert Rotation
    - Pod Security Policy
    - Threat Detection (Not really part of Kubernetes - GKE Cloud Security Command Centre)
    - Sandbox Applications (Providing a tiny kernel for the container - gVisor)
- Applications
    - Batch Applications
    - Workload Controllers, Local Storage
    - GPU access
    - Container Storage Interface
    - (Mention about a Spark operator - a software which manages the running of a Spark cluster)
- Experience