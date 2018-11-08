+++
title = "Trying Google Cloud Build"
description = ""
tags = [
    "devops",
    "google cloud",
]
date = "3018-03-14"
categories = [
    "devops",
    "google cloud",
]
+++

Some quick thougts:

- Google Cloud Build to deploy a simple Google Cloud Function
  - Include tests - if tests failed, don't deploy the solution
- Google Cloud Build to deploy functionality to Kubernetes
  - Build docker containers
  - Test application
  - Migration to another cloud storage (e.g. Staging/Production)
  - Create scripts to set all of these up
