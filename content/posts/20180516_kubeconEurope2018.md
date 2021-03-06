+++
title = "Lessons from Kubecon/CloudNativeCon 2018 Europe"
description = "Summaries from Kubernetes, Cloud Native Applications and tools Conference 2018"
tags = [
    "conference",
    "golang",
    "kubernetes",
]
date = "2018-05-16"
categories = [
    "conference",
    "golang",
    "kubernetes",
]
+++

The following set of summaries are from the Kubecon and Cloud Native Con Europe in Denmark from 2-4 May 2018.

These summaries are from conference talks that I thought provided more interesting thinking points.

The videos for the conference can be found here:  
https://www.youtube.com/watch?v=OUYTNywPk-s&list=PLj6h78yzYM2N8GdbjmhVU65KYm_68qBmo

Below are some of the talks that I found quite interesting (just my own preference)  
I took some of my personal notes so that I don't need to rewatch the videos once more just to get the main point the video seem to talk about.

- [Anatomy of a Production Kubernetes Outage](#anatomy-of-a-production-kubernetes-outage)
- [Cloud Native Landscape Intro](#cloud-native-landscape-intro)
- [Accelerating Kubernetes Native Applications](#accelerating-kubernetes-native-applications)
- [Kubernetes Project Update](#kubernetes-project-update)
- [The Challenges of Migrating 150+ microservices](#the-challenges-of-migrating-150-microservices)
- [Container-Native dev and ops experience](#container-native-dev-and-ops-experience)
- [Container Native observability & security from Google Cloud](#container-native-observability--security-from-google-cloud)
- [Continuously Deliver your Kubernetes Infrastructure](#continuously-deliver-your-kubernetes-infrastructure)

## Anatomy of a Production Kubernetes Outage

{{< youtube OUYTNywPk-s >}}

- Production Outage occured
- Blog Post: https://community.monzo.com/t/resolved-current-account-payments-may-fail-major-outage-27-10-2017/26296/95?u=alexs
- Another blog post: https://community.monzo.com/t/anatomy-of-a-production-kubernetes-outage-presentation/37331
- In summary: Checking for compatability between platform, tools are vital - such checks are vital especially on the platform level when they can cause cascading failures across the applications.
- Fallbacks when systems fail is helpful; in the case above, applications failed but transactions continue running.

## Cloud Native Landscape Intro

{{< youtube _CFgSksTT54 >}}

- Introduction to the cloud native landscape tools and github page
- Github Link: https://github.com/cncf/landscape
- Website Link: https://landscape.cncf.io/
- Get the pdf versions of the landscape from Github

## Accelerating Kubernetes Native Applications

{{< youtube 8iQRJXJHiZ8 >}}

- Operators is a concept that was build on Kubernetes providing the Custom Resource Definitions
- Allows for specific application management; e.g. Managing the running of a database - if a database need to be resized, operators could be programmed to trigger snapshot before switching to a bigger pod which the data can be replicated in. (example only)
- Reasons on why operators are kind of game changing: https://dzone.com/articles/why-kubernetes-operators-are-a-game-changer
- Additional links: https://medium.com/@mtreacher/writing-a-kubernetes-operator-a9b86f19bfb9
- Operator Framework by core os: https://coreos.com/operators/
- Github link to operators: https://github.com/operator-framework/operator-sdk

## Kubernetes Project Update

{{< youtube 2eAOx8E6-5Q >}}

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
  - Stackdriver. Integrates deeply with Prometheus
- Developer Experience
  - Skaffold (Allows debug tool to be attached allowing interactive debugging with custom deployments)

## The Challenges of Migrating 150+ microservices

{{< youtube H06qrNmGqyE >}}

- Tools out there kind of follow the same cycle: Genesis -> Custom Built solutions -> Product Offering -> Commodity.
- Chart from here: https://medium.com/wardleymaps/anticipation-89692e9b0ced
- Link to whole blog post: https://medium.com/wardleymaps
- When companies are big, moving and innovating becomes expensive (its not a technology problem but more of a human, community, company problem). So essentially, one can consider this as _innovation tokens_; tokens that should only be spent wisely, else failure would be result.
- Choose boring technology. http://mcfunley.com/choose-boring-technology
- One way to reduce risk is to run the applications on 2 parallel stacks but it is very expensive in terms of complexity and human effort. When doing this, one needs note of the costs of doing this kind of test
- Such tests have an impact on cost - might be good to rope in the people with this on the test being run, the hypothesis of what that should be happening and the benefits that the company will have

## Container-Native dev and ops experience

{{< youtube 0sh2aWdfBxA >}}

- Talk about the following tool: https://github.com/Azure/draft

## Container Native observability & security from Google Cloud

{{< youtube 8fSNDxA_irY >}}

- Talk about the following tool: gVisor - this tool is a fix for the Dirty Cow vulnerability
- Stackdriver support - Deep prometheus integration - It can import metrics stats over from it to stackdriver to provide the one glass pane to be able to view all applications being monitored in one tool
- Podcast: https://kubernetespodcast.com/
- Blog post talking about podcast: https://cloudplatform.googleblog.com/2018/05/introducing-kubernetes-podcast-from-google.html

## Continuously Deliver your Kubernetes Infrastructure

{{< youtube 1xHmCrd8Qn8 >}}

- Philosophy for setting kubernetes clusters
  - No pet clusters (No special custom configuration for 80 clusters)
  - Always provide the latest stable Kubernetes version
  - Continuous and non-disruptive cluster updates
  - "Fully" automated operations (Able to redeploy by just doing PRs)
- Cluster setup
  - Provision in AWS via cloud formation
  - Etcd stack outside Kubernetes
  - Container Linux
  - Multi-AZ worker nodes
  - HA control plane setup behind ELB
  - Cluster configuration in git
  - e2e test on Jenkins
- Cluster registry
  - List of clusters available of access
- https://github.com/zalando-incubator/kubernetes-on-aws
- https://github.com/zalando-incubator/cluster-lifecycle-manager
- Multiple "channels" of Kubernetes
  - Cluster upgrade moves from dev, alpha, beta clusters
  - dev (Cluster to play around with)
  - alpha (Main infrastructure cluster that is used by infrastructure team for testing)
  - beta (Main cluster rest of org uses)
  - Has e2e tests
  - Conformance tests (https://github.com/cncf/k8s-conformance)
  - Statefulset tests (Test attachment volumes - testing to use redis cluster?)
  - Has monitoring on each cluster to ensure behaviour
  - https://github.com/mikkeloscar/kubernetes-e2e
- Hints for running e2e tests
  - Run with flake attempts=2. Some tests can fail due to autoscaling
  - Update e2e images with each release of Kubernetes
  - Disable broken e2e tests with -skip parameter
  - Remove completed pods from kube-system to make room for other pods of testing to enter (To save money)
