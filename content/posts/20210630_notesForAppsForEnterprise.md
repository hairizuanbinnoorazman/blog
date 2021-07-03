+++
title = "Notes for building apps to be deployed on client infrastructure"
description = "Points to consider when building applications that are targeted to be third party infrastructure"
tags = [
    "google cloud",
]
date = "2021-06-30"
categories = [
    "google cloud",
]
+++

This post is just some notes I took down while attempting to deploy third party applications during my course of work/side projects. This is definitely not an exhaustive list of items to consider but definitely some of the more obvious features that companies would look out for and consider when attempting to install such third party apps and operate it on their infrastructure.

## Data Management

When building third party applications, we may need to store state in some cases. Data needs to be stored in some way such as in a database or object storage or in simple files. In this case, we shouldn't exactly assume that we would know what kind of databases that users of the application would usually use. Some users face restrictions in what kind of databases they could deploy into production. Others might predict that they would use the app heavily and they would be confident that their database of choice would be able to handle it as compared to what we may choose.

In order to allow the usage of multiple types of database, we may need to consider either building that support of multiple databases from the beginning or allow users to build plugins that can be used alongside the application to store the data in the user's own preferred database.

Beyond the choosing of database, we may need to then look into how much data would be stored by the app and how long should this data be stored and how to tune the application such that it would produce less load on database systems. These should be exposed as various tuning options that would allow user to have full control of how the application can impact the user's production environment.

To sum it all, here are some questions to ponder when considering the data management aspects when building third party applications

- Flexibility to support different types of databases/storage. Either have that support built in or provide capability to build plugins which can be run alongside main binaries to support such functionality
- Data retention capability (How long to keep the data). Any mechanism to remove old data?
- Data packing capability. In the case where we need to store large amounts of data, would we be able to alter it such that we can zip and pack the data to reduce usage of storage resources

## Deployment

Ideally, if we're the users of these third party apps, we wouldn't want to build up the deployment artifacts on our own while trying to deploy these apps. There are various aspects that we need to consider when building such artifacts (e.g. dependencies required, security requirements, configuration/initialization files to be created)

With that, if we are to be the builders of these third party apps that are aimed to be deployed at client infrastructures, we would need to be in charge of building such artifacts. The unfortunate thing is, we won't know what is the 

- Docker images
- Helm chart
- Kustomize scripts
- RPMs (Centos Package System)
- DEBs (Ubuntu and Debian Package System)
- Linux executables
- Window executables
- Ansible scripts (maybe?)

We would also need to consider that the binaries could be deployed on various computer architectures such as 32 bit systems, 64 bit systems or arm systems.

For these artifacts, we would need to consider where those artifacts would be made available on. E.g. for docker images, should be put into Dockerhub? Will the frequency of the updates 

In some of the cases such as the helm chart and kustomize scripts - we may need to ensure that the configuration is setup in a flexible manner to ensure that users of these artifacts would be to customize the installation according to their requirements and architecture.

## Permission systems

Some aspects of it would relate to the authentication and authorization when it comes to the usage of the application. This is to ensure that only authorized users would be able to access the data in the application; sometimes, we don't know such data to be "public" even if application is hidden in the user's company's VPN.

Some things to consider:

- Capability to set how much "powers" each user have in term of operating on data/resources in the application being built. E.g. maybe having admin role (which can do full create, read, write capabilities), reader role etc
- Capability to set users on the applications in groups. This brings up a question whether you can nest groups within groups and whether you mix users and groups under a group.
- Capability to integrate application with existing user systems (e.g. ldap in a company, google groups in the case where a company uses Google Workspace to manage their users)

## Operationability

With all applications, we would need to ensure that the application being built can be operated safely in production environments. Some of the things that we need to be concerned about could with regards about monitoring and logging and security of the binaries

Some of the aspects that we need to consider:

- Providing monitoring methodology. Currently, prometheus is one of the popular tools that is being monitor applications and tools. This can be done by providing a prometheus endpoints
- Flexibility to define where the application would send the logs to (e.g. should logs be sent to a file? Or should logs be sent stdout?)
- Level of logs to be provided by the application
- Formatting of logs. At times, some companies may have decided to go for json formatted log formatting to standardize it across applications/components. One reason to do so is to make it easier for their centralized logging system to parse such logs to do analysis on such logs
- Providing of distributed traces to understand the application further although this not exactly too important
- In the case where we provide docker images to be used for deployment. It would be ideal to ensure the image is secure as per user's company's requirements. One way is to utilize small minimalistic base images: e.g. https://github.com/GoogleContainerTools/distroless or alpine images or slim images. Just do know that using these minimalistic images make it harder to build such artifacts (tooling/dependencies may be missing in such minimalistic images)

## Scalability

In some cases, some of the applications might turn out popular in the client's company. There might be a need to scale up or scale out the applications and it would be ideal if there are methodologies/steps/metrics to look out for in an attempt to scale it

Some points to think about:

- A guide on how to scale out application. If application is to be deployed on Kubernetes with a helm chart, one can utilize the HorizontalPodAutoscaler resource and define some default values that clients can kind of use
- It might be good to provide which metrics can be used/based on to scale out the application. We can scale an application based on its CPU usage or Memory usage. However, we can also go with something slightly controversial (e.g. number of items in a queue). However, the target platform needs to have that mechanism to do that sort of scaling.
- Does the application need to rely on cluster mode? Ideally, it would be best to avoid setting up cluster capability since that would make it really hard to maintain/test such applications. In my own opinion, having clustering in application is reserved for stateful applications which doesn't apply for many applications

## Implemented Examples

Some of the above points have been found to be implemented in many of the open source projects out there.

- Jaeger Distributed Tracing project
  - Github Link: https://github.com/jaegertracing/jaeger
  - Documentation Page: https://www.jaegertracing.io/docs/1.23/getting-started/
- Elasticsearch project
  - Definitely a good example of what to follow when attempting to build applications which is aimed to be used by big companies