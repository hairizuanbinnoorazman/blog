+++
title = "Attempting to understand CSI Kubernetes"
description = "Attempting to understand the container storage interface used in Kubernetes"
tags = [
    "kubernetes",
]
date = "2020-05-01"
categories = [
    "kubernetes",
]
+++

NOTE: THIS POST IS NOTES IM TAKING FOR MYSELF WHILE ON THIS JOURNEY. TAKE IT WITH A BAG OF SALT. NOT ALL THINGS MENTIONED HERE IS TRUE - DO YOUR OWN DUE DILIGENCE

This topic is a really hard topic to wrap your head around. Generally, most people don't need to dive this deep in order to understand how kubernetes work but let's just say: I got a tad curious. I was itching to try to learn how to write a storage provisioner that utilizes CSI.

Let's start with the list of links/ideas that we need to grasp:

## Ideas to understand

### Kubernetes overall architecture

User would communicate the needs of the applications via kubectl or other alternative tools to the Kubernetes API server. The API server would then schedule the required resources accordingly before proceeding to inform the kubelet (the binary that runs on nodes etc) of the new "state of the world" of the cluster. It then becomes the kubelet job to try to make it happen.

In the case for CSI, it would seem that kubelet would talk to the storage provisioner on the server. On cloud environments, that would mean that the storage provisioner would proceed to communicate with cloud apis to create virtual disk that would attach to the node which would then make the storage available to the container.

### Communicating over sockets

Within csi spec, there are mentions where one would need to pass socket paths (e.g. tcp://... or unix:///...). The components talk over grpc and would need endpoints to communiate to.

https://eli.thegreenplace.net/2019/unix-domain-sockets-in-go/

This seems to be a more effective way for processes to communicate with each other. As mentioned in the article, seeing that tcp do have overheads for communications that only send small messages to each other, it would make complete sense for communications to be done for unix sockets. Also, commmuncation would come from kubelet to the storage driver. Both binaries/processes are local => hence, there is little need to ensure that the communication channels need to ensure that it can accept communication from outside the node.

### GRPC

GRPC seems to be the most common way of how CSI components communicate with each other.

TLDR version. It's communicating binary on top of TCP

Reasons for doing it is obvious. Reduced overhead in terms of what gets put over the wire. It should also mean less resources being required to marshall and unmarshall the content. The information should immediately be useful for the component without needing resources to understand it.

### Understanding CSI Specification

And this would be hardest one to do among all of the tasks. A whole variety concepts will need to be understood before one can continue developing a storage privisioner with CSI sanely.

The main doc for this:  
https://kubernetes-csi.github.io/docs/developing.html

However, the blog only cover higher ideas that don't cover the details. In order to understand that, it would be good to go read sample code for a sample storage driver: hostpath-plugin

https://github.com/kubernetes-csi/csi-driver-host-path

This driver dynamically creates volumes on host file system on kube nodes.

This url is for tool to help test CSI plugins:  
https://github.com/kubernetes-csi/csi-test/tree/master/pkg/sanity

This is a mock implementation of a CSI tool - it has no functionality but it contains application structure for a CSI plugin to work. Note on the endpoints needed in order to create one

https://github.com/rexray/gocsi/tree/master/mock

It also comes with a CSI client in order to test calls that are to be made to the plugin:

https://github.com/rexray/gocsi/tree/master/csc

### Block storage on a file

This is mainly to understand how hostpath-plugin is able to support block storage support. Since Kubernetes 1.13, support for raw block storage came in. As mentioned in the article, such storage options is meant for more specialized workloads e.g. databases etc.

https://kubernetes.io/blog/2019/03/07/raw-block-volume-support-to-beta/

https://www.jamescoyle.net/how-to/2096-use-a-file-as-a-linux-block-device

Within the hostpath plugin, there are mentions where fallocate is used; it's used when volume requested is of raw block storage type rather than mounted. Alternative approaches are dd and trucate but this seems to cover on why fallocate is being used instead.

http://infotinks.com/dd-fallocate-truncate-making-big-files-quick/
