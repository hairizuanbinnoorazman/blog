+++
title = "Storing Helm in Docker Registries"
description = "Storing Helm in Docker Registries"
tags = [
    "docker",
    "kubernetes",
    "golang",
]
date = "2023-08-23"
categories = [
    "python",
    "kubernetes",
    "golang",
]
+++

We can apparently now store helm charts in Docker registries - this was made available via helm commands since v3.8.0. https://helm.sh/docs/topics/registries/

Now with that being available for use, we can now use it across a variety of storage mechanism (as compared in the past when the artifacts produced through it has to be managed in some of file system and would require some of index file to list all available helm charts available).

To try things out locally, let's try setting up a simple Docker registry on our host machine:

```bash
docker run -d -p 5000:5000 --restart always --name registry registry:2
```

We can then try to push a golang image into it

```bash
docker pull golang
docker tag golang:latest localhost:5000/golang:latest
docker push localhost:5000/golang:latest
```

## Building helm chart and pushing it in

First things first is to ensure that our helm version is valid and has the capability to do the following task of pushing helm charts into oci registries

```bash
helm version
# Output:
# version.BuildInfo{Version:"v3.10.1", GitCommit:"9f88ccb6aee40b9a0535fcc7efea6055e1ef72c9", GitTreeState:"clean", GoVersion:"go1.18.7"}
```

Next step is to build up a helm chart. Here is an example of one:  
https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicHelm

Within this folder, run the following command to package it:

```bash
helm package ./basic-app/
```

This command would create the `basic-app-0.1.0.tgz` file which we can then push the registry

```bash
helm push basic-app-0.1.0.tgz oci://localhost:5000/basic-app
Pushed: localhost:5000/basic-app/basic-app:0.1.0
Digest: sha256:6d3557ff6044f490d535e0cda7bbf979c7879a1380af6cf6a1dc9d8b532d5134
```

With that, we now have a proper place to put our helm artifacts - they can all be centralized in container based registries (since it supports the oci standard). We no longer need to consider putting it in alternative storage locations e.g. a simple filesystem or even blob storage.

More details of this is available on the following documentation page:  
https://helm.sh/docs/topics/registries/