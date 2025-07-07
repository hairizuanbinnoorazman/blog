+++
title = "Speaker Profile"
description = "Social Media lists and list of talks that was done in the past"
date = "2019-01-01"
menu = "main"
weight = "20"
meta = "false"
+++

## Bio

Hairizuan is a Devops Engineer at Kiteworks. He is a avid fan of tools and technologies and has dabbled in various programming languages such as Golang, Python, Elm and R. He is currently one of the co-organizer for the GDG Cloud Singapore meetup group.

## Social Profiles

https://www.linkedin.com/in/hairizuan-noorazman/
https://www.facebook.com/hairizuan.noorazman

Is one of the co-host for the webinars hosted on GDG Cloud Singapore Webinar  
https://www.youtube.com/c/GDGCloudSingapore

Sessionize - Call for papers  
https://sessionize.com/hairizuan/

## Books

Author for the following books

- [Golang for Jobseekers](https://www.amazon.com/Golang-Jobseekers-Unleash-programming-advancement-ebook/dp/B0C7ZVS44M)

## Talks

### Build your own code assessment platform but on Kubernetes

Creating your own code assessment platform but on Kubernetes. This involves creating an application that would be deployed on Kubernetes. This application has the capability to spin up pods that would be able to run submitted code to check for "correctness" of the code etc.

Slides: https://docs.google.com/presentation/d/1XmNMDlMjcEETu-ybw-mnBjIu1igmCd084gQzxRZF3Js/edit?usp=sharing  

### Back to Basics: Deploying an application on a server

A workshop session that covers the basics of application deployment on a server such as:

- scp of application artifacts to the server
- Setup of systemd for the application on server

### Build your own redis

Redis changed their license and that resulted in some companies needing to switch away from Redis. It might be a good opportunity to look at Redis to see how it clicks under the hood - how data is passed from server to redis servers etc (looking and trying to understand the redis protocol). We will then attempt to build a small redis based on that (only covering the critical redis api-s)

Slides: https://docs.google.com/presentation/d/1qM8LUksshhiAkpdg6MLVRuWmY8gJ0beWU2IhWricFa8/edit?usp=sharing  
Videos: https://www.youtube.com/live/BaNEKiJ7blA?si=ga4jSZ0mAN9GA76J&t=3220  

### Build your own code assessment platform

A session about building your own code assessment platform. Particular focus on the sandbox environment to run submitted code which will be implemented via docker for this particular talk. There will be a focus on security configurations needed for docker setup

Slides: https://docs.google.com/presentation/d/1aIRND0mP-42b2ZKcvEJXtEX-31UT66v1BwL61khl-Yo/edit?usp=sharing  

### Feature flags can be surprisingly complicated

Feature flags are usually an after-thought when it comes to building applications. However, there is an entire army of developers that think otherwise. There is now an small set of companies that aim to provide feature flags as a service. There is now even a project in CNCF that aims to standardize this in order to ensure that users are not bound to a single provider. This talk aims to cover this (and more if time permits)

Slides: https://docs.google.com/presentation/d/1fNXmnvnCRZ5Wn9NOzqpX2SwJRjGzFXZuT9EtaY_IWlI/edit#slide=id.p  

### Block Youtube shorts with Chrome Extensions

A quick introduction on how to build a chrome extension in order to block youtube shorts on the youtube website. https://www.hairizuan.com/chrome-extension-to-get-rid-of-youtube-shorts/

Slides: https://docs.google.com/presentation/d/1W6HUNWFyH0SE2PKPbfwWl6k7EBIJ66FQKQr_OAj47N0/edit#slide=id.p  
Code: https://github.com/hairizuanbinnoorazman/youtube-cleanup  

### Using Emulators for Testing Google Cloud Datastore

Talk is about the situation where we would want to test an application that relies on Google Cloud Datastore locally. Google Cloud Datastore is a cloud based service - which raises the question of how a developer can test it locally, ideally without requiring to create a separate Google Cloud Project to safely test the changes. 

Slides: https://docs.google.com/presentation/d/1qtzs2n5ChbXwi-ZhZtqwf_bSYApM1_5q49_mvrFRMrY/edit#slide=id.p

### Deploying apps using workload identity on GKE

Talk on introducing audience to deployment of applications on Google Kubernetes Engine. The application being used for demo would need to contact a Google APIs. The demo would consist having the application deployed in a Kubernetes cluster without needing a service account file for authentication of api requests.

Slides: https://docs.google.com/presentation/d/1-Vsy_1PpQV5wJNyTYuw4OKhyLTt_w_imaT4XPoyIStg/edit#slide=id.p
Slides (Devfest edition): https://docs.google.com/presentation/d/1MYLJDINrvph-XBW08oITfftWy0g9HE8lu2qoeF7ObMU/edit#slide=id.g26290ab0c45_0_86  

### Introduction to Cloud

Talk on introducing people unfamiliar with cloud to cloud technologies/platforms. Used angle of understanding cloud from feature set available

Video Stream: https://www.twitch.tv/videos/1039052712  
Video: https://www.youtube.com/watch?v=N0UA7DgeFBY  

### Kubernetes HPA with Custom Metrics

A demo of how to utilize an application's custom metrics

Slides: https://docs.google.com/presentation/d/159fA2Q12nSaldHD--0Ypln_tzruVNiM36edAAUaRoY0/edit?usp=sharing  
Video Recording: https://www.youtube.com/watch?v=IxDqs7387YI

### Deploy via spreadsheet? Thats a bad idea

Demo of deploying apps into k8s clusters but controlled via Google Spreadsheets

Slides: https://docs.google.com/presentation/d/1YFnL9oirzsaVvqTVM6HshnfVFwqboRzv1KhytqCNQO0/edit#slide=id.p
Video Recording: https://www.youtube.com/watch?v=4KZkBJFOgrQ&t=5106s

### Interesting Features in GKE

Covering on Workload Identity, Config Connector, Managed Application Delivery etc
 
Slides: https://docs.google.com/presentation/d/1ptjcfpRuoKGqAsSr7O-USulBEcu9JdQpEZ3y3yQ7Tuk/edit?usp=sharing  
Video Recording: https://www.youtube.com/watch?v=xlWX7iNKag8

### Introduction to Skaffold

Introductory session to skaffold, reasons for using it as well as how to quickly get started with the tool

Video: https://www.youtube.com/watch?v=xNq-aFohfgk

### Skaffold with Google Cloud Build

Talk on using Skaffold to deploy applications to Kubernetes Clusters. Instead of using local docker engine runtime; one would use the Google Cloud Build as the platform to build the image artifacts that would deployed to the cluster

This is mostly a demo session

### Quick tour of Knative

A quick tour around the internals of how Knative works under the hood. Knative is the platform that powers Google Cloud Run; this talk explores the various pieces of technologies that one would need to run if one starts from just plain old Virtual Machines.

Note: Video Recording of demo this time failed (due to typo)

Event: Fosassia 2020  
Blog: https://www.hairizuan.com/trying-knative-from-scratch/  
Video Recording: https://youtu.be/F71rvTQ8unA

### Generating videos from slides on applications served from Google Cloud Run

Using Google Cloud Run to create a bunch of services which when combined together would convert presentation slide pdfs and scripts (not programming script but a script on what to say during a presentation) into a video. The following set of services is build by using Google Cloud Run and Google Text to Speech and Google Cloud Storage and Google Datastore; all deployed via Google Cloud Build

Slides: https://docs.google.com/presentation/d/1Vuv7C1rNGbKdOvpJji5QNiqwvsPvHF6uWzNNEsIthlQ/

### GCSFuse; Heard of it

An lightning talk to give an introduction to GCSFuse and the Fuse common interface.

Slides: https://docs.google.com/presentation/d/1MWEhJIHRgO60Bc-4HhjdIFSA1L2Z3aOu1lIZl6fWVqE

### Introduction to Stackdriver

An introduction to stackdriver, a feature in the Google Cloud Platform. It provides monitoring, logging, profiling services. A golang web application is used an example to demonstrate on how to get such capbilities set up.

Slides: https://docs.google.com/presentation/d/1JtV8N9in039VdtJzz7XN4UcxGHYuowxJQ0b8TOfGn54  
Video Recording: https://engineers.sg/video/google-cloud-next-2019-singapore-using-stackdriver-effectively--3402

### Introduction to Cloud Run

An introduction to Google Cloud Run, a newly announced serverless solution which allows one to deploy any runtime and any software and let Google manage it. The main piece of this presentation is a demonstration of how to deploy a service onto Google Cloud Run via Google Cloud Console GUI

Slides: https://docs.google.com/presentation/d/1M8EhARDBY33IefEz356NhdUkkSyUZo1tHZBkMt-NtpE  
Video: https://www.youtube.com/watch?v=n1wtjEmb7eI  
Blog Post: https://www.hairizuan.com/introduction-to-google-cloud-run/

### Triggering analytics with serverless functions

Using the various serverless functions to trigger different workflows. Demonstrate the usage of different triggers from Google Cloud Platform to run analytical workloads. Presented during Google Cloud Devfest 2018, October 2018

Slides: https://docs.google.com/presentation/d/1trt8SyQYSgUfx8AfHZ7Pt8_VzfIqEsJerpQYqhQ-MIw

### Using Google Cloud Functions for Analytics Workloads

Creating a slack bot that could analyze and return graphs on meetup stats on a single meetup event. This is done by creating an API via Google Cloud Functions. Presented during Google Cloud Next Extended Singapore 2018, August 2018

Video Recording: https://www.youtube.com/watch?v=OYv8nyA8pj8  
Slides: https://docs.google.com/presentation/d/1H05sgx7W83_NlNV2cGdjBUBsU1q1PuRSxwe3E88Ybyg/

### Quickstart Kubernetes

An overview of a variety of concepts such as docker containers as well as Kubernetes terminology which is needed before introducing someone to the Kubernetes tool. Presented during Google Devfest Singapore 2017, October 2017

Slides: https://docs.google.com/presentation/d/1KW9jwpD10vNm7itrDZD8m0X9zya8jwISl_bPpYcw1_M

### From Analysis to Boardroom: Google Slides presentations via R

Went through the reasons for automating analysis work and provided several code snippets on how to get automated analysis when using the R programming language. Presented during Google IO Extended 2017 event, July 2017

This is a Demo only session. No slides are available here.

## Sessions

| Date       | Event Name                            | Event Link                                                  | Topic |
| :--------: | :------------------------------------ | :---------------------------------------------------------- | ----- |
| 2025-06-14 | GDG Next Extended SG 2025             | https://gdg.community.dev/events/details/google-gdg-singapore-presents-google-cloud-next-extended-singapore-2025/cohost-gdg-singapore | [Deploying apps using workload identity on GKE](/speaker-profile#deploying-apps-using-workload-identity-on-gke) |
| 2024-11-30 | GDG Cloud Devfest KL 2024             | https://gdg.community.dev/events/details/google-gdg-cloud-kl-presents-gdg-cloud-kl-devfest-2024/ | [Feature flags can be surprisingly complicated](/speaker-profile#feature-flags-can-be-surprisingly-complicated) |
| 2024-11-23 | GDG Devfest Singapore 2024            | https://gdg.community.dev/events/details/google-gdg-singapore-presents-devfest-singapore-2024-gemini-conference/ | [Build your own code assessment platform but on Kubernetes](/speaker-profile#build-your-own-code-assessment-platform-but-on-kubernetes) |
| 2024-11-23 | GDG Devfest Singapore 2024            | https://gdg.community.dev/events/details/google-gdg-singapore-presents-devfest-singapore-2024-workshop/cohost-gdg-singapore | [Back to Basics: Deploying an application on a server](/speaker-profile#back-to-basics-deploying-an-application-on-a-server) |
| 2024-11-16 | GDG Cloud Devfest Surabaya 2024       | https://gdg.community.dev/events/details/google-gdg-cloud-surabaya-presents-devfest-cloud-surabaya-2024/ | [Build your own redis](/speaker-profile#build-your-own-redis) |
| 2024-08-29 | GDG Cloud Singapore August Meetup     | https://gdg.community.dev/events/details/google-gdg-cloud-singapore-presents-gdg-cloud-singapore-august-meetup/ | [Build your own redis](/speaker-profile#build-your-own-redis) |
| 2024-06-22 | GDG Cloud KL IO Extended 2024         | https://gdg.community.dev/events/details/google-gdg-cloud-kl-presents-gdg-cloud-kl-io-extended-2024/ | [Build your own redis](/speaker-profile#build-your-own-redis) |
| 2024-06-01 | GDG Cloud Singapore IO Extended 2024  | https://gdg.community.dev/events/details/google-gdg-cloud-singapore-presents-google-io-extended-singapore-2024/ | [Build your own code assessment platform](/speaker-profile#build-your-own-code-assessment-platform) |
| 2023-12-02 | GDG KL Devfest 2023                   | https://gdg.community.dev/events/details/google-gdg-kuala-lumpur-presents-devfest-2023-kuala-lumpur/ | [Deploying apps using workload identity on GKE](/speaker-profile#deploying-apps-using-workload-identity-on-gke) |
| 2023-11-18 | GDG Singapore Devfest 2023            | https://sites.google.com/view/devfest-singapore-2023/speakers | [Feature flags can be surprisingly complicated](/speaker-profile#feature-flags-can-be-surprisingly-complicated) |
| 2023-10-14 | Geekcamp SG 2023                      | https://geekcamp.sg/                                        | [Block Youtube shorts with Chrome Extensions](/speaker-profile#block-youtube-shorts-with-chrome-extensions) |
| 2023-07-29 | I/O Extended Singapore 2023           | https://gdg.community.dev/events/details/google-gdg-cloud-singapore-presents-google-io-extended-cloud-edition-2023/ | [Using Emulators for Testing Google Cloud Datastore](/speaker-profile#using-emulators-for-testing-google-cloud-datastore) |
| 2023-07-18 | KubernetesSG Meetup Jul 2023          | https://www.meetup.com/k8s-sg/events/294559504/             | [Deploying apps using workload identity on GKE](/speaker-profile#deploying-apps-using-workload-identity-on-gke) |
| 2023-02-20 | KubernetesSG Meetup Feb 2023          | https://www.meetup.com/k8s-sg/events/291463340/             | [Kubernetes HPA with Custom Metrics](/speaker-profile#kubernetes-hpa-with-custom-metrics) |
| 2022-12-15 | GDSC MUM x Google Singapore           | https://gdsc.community.dev/events/details/developer-student-clubs-monash-university-malaysia-presents-gdsc-mum-x-google-singapore/ | [Introduction to Cloud Run](/speaker-profile#introduction-to-cloud-run) |
| 2022-05-12 | Introduction to Cloud                 | https://www.youtube.com/watch?v=N0UA7DgeFBY&ab_channel=GoogleDeveloperStudentClubPSBAcademy | [Introduction to Cloud](/speaker-profile#introduction-to-cloud) |
| 2021-06-24 | GDG Cloud Extended KL 2021            | https://gdg.community.dev/events/details/google-gdg-cloud-kl-presents-google-io-extended-gdg-cloud-kl/ | [Introduction to Cloud Run](/speaker-profile#introduction-to-cloud-run) |
| 2020-10-31 | GDG Cloud Devfest 2020                | https://www.youtube.com/watch?v=4KZkBJFOgrQ                 | [Deploy via spreadsheet? Thats a bad idea](/speaker-profile#deploy-via-spreadsheet-thats-a-bad-idea) |
| 2020-06-23 | June Devrel Google Cloud Talks        | No event link                                               | [Skaffold with Google Cloud Build](/speaker-profile#skaffold-with-google-cloud-build) |
| 2020-06-11 | Kubernetes June 2020 Meetup           | https://www.meetup.com/Singapore-Kubernetes-User-Group/events/268492981/ | [Introduction to Skaffold](/speaker-profile#introduction-to-skaffold) |
| 2020-05-07 | GDG Cloud Singapore Webinar           | https://www.meetup.com/GDG-Cloud-Singapore/events/270423553 | [Interesting Features in GKE](/speaker-profile#interesting-features-in-gke) |
| 2020-03-20 | Fossasia 2020                         | https://2020.fossasia.org/event/schedule.html#6098          | [Quick tour of Knative](/speaker-profile#quick-tour-of-knative) |
| 2019-11-09 | GDG Cloud Singapore Devfest           | https://www.meetup.com/GDG-Cloud-Singapore/events/264449620 | [Introduction to Skaffold](/speaker-profile#introduction-to-skaffold) |
| 2019-10-23 | La Kopi - Serverless                  | https://events.withgoogle.com/la-kopi-serverless/           | [Generating videos from slides on applications served from Google Cloud Run](/speaker-profile#generating-videos-from-slides-on-applications-served-from-google-cloud-run) |
| 2019-07-24 | GDG Cloud Singapore Meetup July 2019  | https://www.meetup.com/gdg-cloud-singapore/events/262726983 | [GCSFuse; Heard of it](/speaker-profile#gcsfuse-heard-of-it) |
| 2019-06-22 | io19 Extended                         | https://www.meetup.com/gdg-singapore/events/261587580/      | [Introduction to Cloud Run](/speaker-profile#introduction-to-cloud-run) |
| 2019-06-01 | Cloud Next Extended SG - Data Edition | https://www.meetup.com/gdg-cloud-singapore/events/258359490 | [Introduction to Stackdriver](/speaker-profile#introduction-to-stackdriver) |
| 2019-04-24 | Cloud Next Extended SG                | https://www.meetup.com/gdg-cloud-singapore/events/259734957 | [Introduction to Cloud Run](/speaker-profile#introduction-to-cloud-run) |
| 2018-10-27 | Cloud Devfest 2018                    | https://www.meetup.com/GCPUGSG/events/253546454/            | [Triggering analytics with serverless functions](/speaker-profile#triggering-analytics-with-serverless-functions) |
| 2018-08-25 | Google Cloud Next 2018                | https://www.meetup.com/GCPUGSG/events/251921227/            | [Using Google Cloud Functions for Analytics Workloads](/speaker-profile#using-google-cloud-functions-for-analytics-workloads) |
| 2017-10-28 | GDG Devfest 2017 Singapore            | https://devfest17.peatix.com/                               | [Quickstart Kubernetes](/speaker-profile#quickstart-kubernetes) |
| 2017-07-01 | I/O Extended 2017 Singapore           | https://peatix.com/event/258914                             | [From Analysis to Boardroom: Google Slides presentations via R](/speaker-profile#from-analysis-to-boardroom-google-slides-presentations-via-r) |
