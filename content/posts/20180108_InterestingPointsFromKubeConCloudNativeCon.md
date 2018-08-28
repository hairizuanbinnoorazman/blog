+++
title = "Interesting Points from Kubecon/Native con 2017"
description = "Interesting Points from Kubecon/Nativecon 2017"
tags = [
    "conference",
]
date = "2018-01-02"
categories = [
    "conference",
]
+++

Full Playlist can be found here:
https://www.youtube.com/watch?v=Z3aBWkNXnhw&list=PLj6h78yzYM2P-3-xqvmWaZbbI1sW-ulZb

Cloud Native Landscape:
https://github.com/cncf/landscape

- [Keynote: Can 100 Million Developers Use Kubernetes?](#keynote-can-100-million-developers-use-kubernetes)
- [Kubernetes: This Job is Too Hard: Building New Tools, Patterns and Paradigms to Democratize](#kubernetes-this-job-is-too-hard-building-new-tools-patterns-and-paradigms-to-democratize)
- [Weaving the Service Mesh](#weaving-the-service-mesh)
- [Microservices, Service Mesh, and CI/CD Pipelines: Making It All Work Together](#microservices-service-mesh-and-cicd-pipelines-making-it-all-work-together)
- [Developing Locally with Kubernetes](#developing-locally-with-kubernetes)
- [State of Serverless](#state-of-serverless)
- [Keynote: What's Next? Getting Excited about Kubernetes in 2018](#keynote-whats-next-getting-excited-about-kubernetes-in-2018)
- [Keynote: Manage the App on Kubernetes](#keynote-manage-the-app-on-kubernetes)

Video References

## Keynote: Can 100 Million Developers Use Kubernetes?

- Video Link: https://www.youtube.com/watch?v=21l8v6eObcc
- Summary: Talk is more philosophical rather than technical; thinking about who are going to be the new users of the Kubernetes platform etc (youths etc) - how to get such people understand and learn cloud primitives
- Mention about Open Faas: https://github.com/openfaas/faas
- Mention about Minio: https://www.minio.io/

## Kubernetes: This Job is Too Hard: Building New Tools, Patterns and Paradigms to Democratize

- Video Link: https://www.youtube.com/watch?v=gCQfFXSHSxw
- Summary: Raise a view where it is really quite difficult to
- Mention about metaparticle project: https://metaparticle.io/

## Weaving the Service Mesh

- Video Link: https://www.youtube.com/watch?v=WFEllbmRI8U
- Summary: Overview of the Istio Service Mesh Project
  - Nice Service Mesh Features
  - Observability
  - Resilency
  - Traffic Control
  - Security
  - Policy Enforcement
  - Zero Code Change

## Microservices, Service Mesh, and CI/CD Pipelines: Making It All Work Together

- Video Link: https://www.youtube.com/watch?v=UbLG_qUyCgM
- Summary: Overview of how to have a such a pipeline to develop and deploy applications quickly and the tools that can be used to do so.
- https://open.microsoft.com/2017/10/23/announcing-brigade-event-driven-scripting-kubernetes/
- https://brigade.sh/
- https://draft.sh/
- Kashti - A dashboard project built on top of Brigade: https://github.com/Azure/kashti

## Developing Locally with Kubernetes

- Video Link: https://www.youtube.com/watch?v=_W6O_pfA00s
- Summary: How to introduce Kubernetes to developers seeing that Kubernetes is more of a ops tool rather than a developer tool
- http://gist-reveal.it/bit.ly/k8s-workshops#/a-modular-workshop-series-for-learning-kubernetes
- https://github.com/datawire/telepresence

## State of Serverless

- https://www.youtube.com/watch?v=SNJipRS8qxw
- List of Serverless Platforms out there...
  - Apache Openwhisk: https://openwhisk.apache.org/
  - AWS Lambda: https://aws.amazon.com/lambda/
  - Google Cloud Functions: https://cloud.google.com/functions/
  - Kubeless: http://kubeless.io/
  - Fission: http://fission.io/
  - Nuclio: https://nuclio.io/
  - Iron Functions http://open.iron.io/
  - Openfaas https://www.openfaas.com/

## Keynote: What's Next? Getting Excited about Kubernetes in 2018

- Video Link: https://www.youtube.com/watch?v=lUnD9SJDgo8
- Build Faster, Smarter, Better
- Inspiration from the Ruby on Rails community - Make it very easier to just add one more thing to an application to make the application more useful quicker.
- The Year of the Service Mesh. Making the microservices easier to get it up. Handle the harder parts of distribution applications
  - Istio
  - Envoy
  - Conduit
- Make Data Workloads Easier
  - Making it easier to deploy Machine Learning Applications on the Kubernetes platform
  - GPU support?
- Integrating Serverless Natively?
  - Apache Openwhisk
  - Fission
  - Kubeless
  - Some common patterns
    - Event driven
    - Idling
    - Simple build
    - Fast start up
- Defining apps via configurations tools (Improve app and kube configurations)
  - Helm
  - kubecfg
  - ksonnet
  - kompose
  - kedge
  - app-def-wg (App Definitions Working Group)
  - https://github.com/kubernetes/community/tree/master/wg-app-def
- Change how we operate
  - Extensible and security identities
    - Istio
    - Kerberos
    - Spiffe
    - Container identity working group
- Policy, Multi-tenancy, Integration
  - LDAP
  - Open Policy Agent
    - Better container runtimes/VM
- Interesting Projects...
  - https://github.com/appscode/kubed
  - https://github.com/heptio/ark
  - https://github.com/cloudnativelabs/kube-router
  - https://github.com/GoogleCloudPlatform/kube-metacontroller

## Keynote: Manage the App on Kubernetes

- Video Link: https://www.youtube.com/watch?v=ul624nYC8pw
- Questions to answer:
  - What app types are there? Versions?
  - What app instances are deployed? How many? Where?
  - What is the app instance health? How much does it cost?
  - Who are the app owners? Who gets paged?
  - What CI pipelines associate with each app?
- Some of the resources in an attempt to have this (Spreadsheet, App Wiki, Tribal Knowledge)
  - Owners
  - Dashboards
  - Metrics/SLAs
  - Docs
- https://coreos.com/open-cloud-services/
  - Create a shared toolkit
  - App Catalog
  - App Types
  - App Versions
  - App Instances
- https://github.com/kubernetes/community/tree/master/wg-app-def
