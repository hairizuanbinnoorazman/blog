+++
title = "Speaker Profile"
description = "Social Media lists and list of talks that was done in the past"
date = "2019-01-01"
menu = "main"
weight = "20"
meta = "false"
+++

## Bio

Hairizuan is a Devops Engineer at Acronis. He is a avid fan of tools and technologies and has dabbled in various programming languages such as Golang, Python and R. He is currently one of the co-organizer for the GDG Cloud Singapore meetup group.

## Social Profiles

https://www.linkedin.com/in/hairizuan-noorazman/
https://www.facebook.com/hairizuan.noorazman

Is one of the co-host for the webinars hosted on GDG Cloud Singapore Webinar  
https://www.youtube.com/c/GDGCloudSingapore

## Talks

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
