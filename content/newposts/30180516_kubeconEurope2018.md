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

- Video Link: https://www.youtube.com/watch?v=OUYTNywPk-s&list=PLj6h78yzYM2N8GdbjmhVU65KYm_68qBmo
- Production Outage occured
- Blog Post: https://community.monzo.com/t/resolved-current-account-payments-may-fail-major-outage-27-10-2017/26296/95?u=alexs
- Another blog post: https://community.monzo.com/t/anatomy-of-a-production-kubernetes-outage-presentation/37331
- In summary: Checking for compatability between platform, tools are vital - such checks are vital especially on the platform level when they can cause cascading failures across the applications.
- Fallbacks when systems fail is helpful; in the case above, applications failed but transactions continue running.


