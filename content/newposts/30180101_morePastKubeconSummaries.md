+++
title = "More Kubecon Summaries from the past"
description = "Summaries of Kubecon and Nativecon videos from 2017 and before"
tags = [
    "kubernetes",
]
date = "3018-05-02"
categories = [
    "kubernetes",
]
+++

Below are summaries of some of the videos from Kubecon/Nativecon that might be useful. Past videos might sometimes be useful as they might cover critical basic topics and concepts. Those basic topics and concepts would be hard to find again in more recent conferences.

- [Writing a Custom Controller: Extending the Functionality of Your Cluster](#writing-a-custom-controller-extending-the-functionality-of-your-cluster)
- [Extending the Kubernetes API: What the Docs Don't Tell You](#extending-the-kubernetes-api-what-the-docs-dont-tell-you)
- [Using Kubernetes API from Go](#using-kubernetes-api-from-go)
- [Extending Kubernetes 101](#extending-kubernetes-101)
- [Certifik8s: All You Need to Know About Certificates in Kubernetes](#certifik8s-all-you-need-to-know-about-certificates-in-kubernetes)
- [Effective RBAC](#effective-rbac)
- [Helm Chart Patterns](#helm-chart-patterns)
- [Kubernetes Feature Prototyping with External Controllers and Custom Resource Definitions](#kubernetes-feature-prototyping-with-external-controllers-and-custom-resource-definitions)
- [Self-Hosted Kubernetes: How and Why](#self-hosted-kubernetes-how-and-why)
- [kubeadm Cluster Creation Internals: From Self-Hosting to Upgradability and HA](#kubeadm-cluster-creation-internals-from-self-hosting-to-upgradability-and-ha)
- [Kube-native Postgres](#kube-native-postgres)

## Writing a Custom Controller: Extending the Functionality of Your Cluster

{< youtube "\_BuqPMlXfpE" >}

- CloudNativecon 2017 Europe

## Extending the Kubernetes API: What the Docs Don't Tell You

{< youtube PYLFZVv68lM >}

- CloudNativecon 2017 North America

## Using Kubernetes API from Go

{< youtube QIMz4V9WxVc >}

- CloudNativecon 2017 North America
- Refer to the following page for more info: https://kubernetes.io/docs/concepts/overview/components/#addons
- Kubernetes Master
  - API Server
  - etcd
  - Scheduler
  - Controller Manager
  - Cloud Provider Controller
- Kubernetes Worker
  - Kubelet
  - Kube-proxy
  - CRI
- Custom Controller can talk to api server which can be used to handle custom resources on Kubernetes
- Codebase: https://github.com/alena1108/kubecon2017
  - Monitor k8s nodes
  - Alert when storage occupied by images/changes
- Some potential tools that were used:
  - [go-skel](https://github.com/rancher/go-skel)
  - [trash](https://github.com/rancher/trash)
  - [dapper](https://github.com/rancher/dapper)
- When using `client-go` vendor, ensure you're using a compatible version with the kubernetes cluster. https://github.com/kubernetes/client-go
  - Need to decide to run as part of cluster/outside cluster
  - One way when developing apps that is meant to run cluster and shorten development cycle is to run outside cluster, and when it's time to release it, try it out in cluster. Reduce development lifecycle by not requiring developer to keep trying the app out by pushing each change into cluster; can just compile binary and immediately run it.

## Extending Kubernetes 101

{< youtube yn04ERW0SbI >}

- CloudNativecon 2017 North America

## Certifik8s: All You Need to Know About Certificates in Kubernetes

{< youtube gXz4cq3PKdg >}

- CloudNativecon 2017 North America

## Effective RBAC

{< youtube Nw1ymxcLIDI >}

- CloudNativecon 2017 North America

## Helm Chart Patterns

{< youtube WugC_mbbiWU >}

- CloudNativecon 2017 North America

## Kubernetes Feature Prototyping with External Controllers and Custom Resource Definitions

{< youtube fnSNPgwXcUc >}

- CloudNativecon 2017 North America

## Self-Hosted Kubernetes: How and Why

{< youtube jIZ8NaR7msI >}

- CloudNativecon 2017 North America

## kubeadm Cluster Creation Internals: From Self-Hosting to Upgradability and HA

{< youtube YCOWQIFVAbg >}

- CloudNativecon2017 North America

## Kube-native Postgres

{< youtube Zn1vd7sQ_bc >}

- CloudNativecon 2017 North America
