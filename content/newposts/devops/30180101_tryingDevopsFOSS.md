+++
title = "Sticking to FOSS software"
description = "Sticking to FOSS software to deploy applications"
tags = [
    "ansible",
    "devops",
]
date = "3018-03-14"
categories = [
    "ansible",
    "devops",
]
+++

An attempt to use much more FOSS software to handle all our services. Some of the services:

- gitlab. Attempt to host and run gitlab on a virtual machine
- rocket chat. Attempt to host and run chat application systems
- kubernetes. Hosting platform for our applications
- jenkins. For continuous integration and testing of applications
- minio. For running of oss blob storage. Less reliance on cloud storage solutions
- hadoop + spark. This is to handle big data jobs
- airflow. This is to handle data orchestration across services
- cms systems. https://github.com/ponzu-cms/ponzu

Lets's make it even more challenging and have multiple scenarios for this:

- Where every service has to be in the same server
- Where each of the task servers are in its own server but the database as well as the queue services and web service are still in one main server
- Where queue service is replace with Google Pubsub and database replace with Google Cloud Sql service but the rest of the services

A few things we would want to also setup for a more complete picture of this:

- Setup jenkins.
  - Jenkins would be used to receive build tasks from github
  - It would then test and build said binaries and drop them into Google Cloud Storage under a build bucket
- Alternatively,
  - Google Cloud Build could potentially be used as an initial first cut
- One of the steps ansible would need to do is to copy down the build binaries from the bucket and deploy it onto mentioned servers above
