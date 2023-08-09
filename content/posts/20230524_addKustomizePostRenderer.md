+++
title = "Altering outputs of helm installations with post-renderer via kustomize"
description = "Using kustomize scripts to alter post-rendering of kubernetes manifest files"
tags = [
    "golang",
    "kubernetes",
]
date = "2023-05-24"
categories = [
    "golang",
    "kubernetes",
]
+++

When one thinks of Kubernetes and deploying stuff into Kubernetes, one of the usual ways to get such stuff into Kubernetes is through the use of Kubernetes manifest files. Kubernetes manifest files describe various different resources in Kubernetes cluster - some primary examples that are often used are `Deployment`, `Configmap`, `Secret`, `Service` and even `Ingress` Kubernetes resources/objects.

However, managing a whole bunch of Kubernetes resources is usually quite troublesome - there is a usual need for templating when trying to get such resources into the clusters. Helm is a tool that came up in order to solve this. With helm, we can package a bunch of kubernetes resources in a single "package" (it's simply a tar file) and deploy the whole lot into cluster, we won't miss a resource by accident etc.

However, there are cases where sometimes, the Kubernetes manifest files generated from helm doesn't fully fit their requirements - there could be a possibility that the Helm chart isn't flexible enough to accept some of the stuff they need (e.g. setting of additional annotations/labels - the author of the Helm chart need to ensure that the field accepts the variable from the `values.yaml` that is to be passed in via Helm cli tool). 

Also, let's pose another scenario where a maintainer of a DC needs to be deploy 50 helm charts on the cluster. Let's say the cluster is "limited" in resources and we would need to define lower initial replicas to be run on the cluster at the beginning. It would be pain to have the maintainer of DC to go in to modify `values.yaml` that is to be fed to each of the helm chart - we can't assume that the `replicas` field in the `values.yaml` is the same across the helm charts. If one is to take a look at some of the open source code helm charts - all of them are set differently...

e.g. https://artifacthub.io/packages/helm/bitnami/minio
```yaml
statefulsets:
    replicaCount: 4
```

e.g. https://artifacthub.io/packages/helm/grafana/grafana
```yaml
replicas: 1
```

e.g. https://artifacthub.io/packages/helm/bitnami/wordpress
```yaml
replicaCount: 1
```

Some of the helm chart even have "sub" components (they declare multiple deployments) and those also have replicas that needs to be managed.

With all that in mind, we can't use and standardize the `values.yaml`. However, we do know that the generated yaml are valid Kubernetes manifest files and those would be standardized. We can technically do some yaml manipulation and then have helm manage the installation.

Helm has a flag called `--post-renderer` where we can have some executable that we can pass to manipulate the generated Kubernetes manifest files.

Refer to the following example application and Helm chart: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicHelm

We can use the a usual yaml manipulation tool - `yq` to manipulate the generated yaml. If we have a shell script such as the following:

```bash
#!/bin/bash
yq eval '.metadata.annotations.cool = "miao"' -
```

Don't forget that we would need to set the file permissins for `yahoo.sh` to be executable. We can then run the following command:

```bash
helm template zolo ./basic-app --post-renderer ./yahoo.sh
```

It should generate the following (this is just a small snippet - the full output is pretty long). It is just an example based of one of the resources:

```yaml
...
# Source: basic-app/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zolo-basic-app
  labels:
    helm.sh/chart: basic-app-0.1.0
    app.kubernetes.io/name: basic-app
    app.kubernetes.io/instance: zolo
    app.kubernetes.io/version: "1.16.0"
    app.kubernetes.io/managed-by: Helm
  annotations:
    cool: miao
spec:
  replicas: 1
  selector:
...
```

Take note of the annotations added according to our shell script.

Although it is possible to use `yq` tooling to manipulate the output Kubernetes manifest, it is usually not specific enough. `yq` tool is a generic tool that is ok to manipuate generic `yaml` files. However, if we need more specificity, then it might be better to use the kustomie tool that is able to manipulate kubernetes manifest files. It has more specificity and provides way more flexibility (it even integrated jsonpatch mechanism)

Let's say if we wanted to set replicas for all deployment objects in generated kubernetes manifest files. We would first need to define a shell script to spit out the generated kubernetes manifest file to a physical file. We can then use the kustomize on generated file, afterwhich we can then view the post-rendered yaml files.

kustomize.sh

```bash
#!/bin/bash

cat <&0 > all.yaml

kustomize build . && rm all.yaml
```

Here is the kustomize.yaml that we can apply on the generated `all.yaml`

```bash
# Refer to the following documentation page: 
# https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/
# 
# Comment out resources accordingly to which is to be applied
resources:
- all.yaml
# - alteredclient.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 5
    target:
      group: apps
      version: v1
      kind: Deployment
```

We can run the above by running the following:

```bash
helm template zolo ./basic-app --post-renderer ./kustomize.sh
```

With that, we would alter all deployment objects generated from the generated chart to have 5 replicas.

One question I immediately pondered while checking out this functionality is "why not simply send the post-rendering via piping it through scripts?". An example:

```bash
helm template zolo ./basic-app | yq eval '.metadata.annotations.cool = "miao"' -
```

Technically, this is possible - however, we've been using the `template` subcommand till now. One of the usual subcommands some people use is to utilzie the `upgrade` or `install` subcommands provided via the helm cli tool. An example would be something like this:

```bash
helm upgrade --install zolo ./basic-app
```

We would use this command so that we can make use some of helm's lifecycle application installation tooling, namely the pre-install and post-install hooks. Kubernetes manifest files in generated don't have any order when we apply it to the cluster but we can set the ordering within helm chart. In order to make use of all of helm's application lifecycle features, we can simply add on the `--post-renderer` flag - and that would allow us to simply continue with installations with modifications on the generated Kubernetes manifest file.

```bash
helm upgrade --install --post-renderer ./kustomize.sh zolo ./basic-app
```