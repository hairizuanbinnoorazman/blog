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

This is definitely not an exhaustive list of items to consider but definitely some of the more obvious features that client side users would look out for and consider when attempting to install such third party apps and operate it on their infrastructure.

This list was compiled while I was attempting to deploy third party applications during my course of work/side projects.

From this point onwards, we would need to assume that when we are building applications here - we would be referring to the point that such applications are targeted to be deployed on client side (someone else would take that application and deploy/manage it on their architecture).

## Data Management

When building applications, we may need to store state in some cases. Data needs to be stored in some way such as in a database or object storage or in simple files. In this case, we shouldn't exactly assume that we would know what kind of databases that users of the application would usually use. Some users face restrictions in what kind of databases they could deploy into production. Others might predict that they would use the app heavily and they would be confident that their database of choice would be able to handle it as compared to what we may choose.

In order to allow the usage of multiple types of database, we may need to consider either building that support of multiple databases from the beginning or allow users to build plugins that can be used alongside the application to store the data in the user's own preferred database.

Beyond the choosing of database, we may need to then look into how much data would be stored by the app and how long should this data be stored and how to tune the application such that it would produce less load on database systems. These should be exposed as various tuning options that would allow user to have full control of how the application can impact the user's production environment.

To sum it all, here are some questions to ponder when considering the data management aspects when building third party applications

- Flexibility to support different types of databases/storage. Either have that support built in or provide capability to build plugins which can be run alongside main binaries to support such functionality
- Data retention capability (How long to keep the data). Any mechanism to remove old data?
- Data packing capability. In the case where we need to store large amounts of data, would we be able to alter it such that we can zip and pack the data to reduce usage of storage resources

## Deployment

Ideally, if we're the users of these apps, we wouldn't want to build up the deployment artifacts on our own while trying to deploy them. There are too many aspects that they would need to consider when building such artifacts (e.g. dependencies required, security requirements, configuration/initialization files to be created) and if users are expected to think of these concerns, that would be make it harder for them to adopt into their companies. (Unless there is a strong compelling reason to use them)

With that, if we are to be the builders of these apps that are aimed to be deployed at client infrastructures, it would be ideal for usto be in charge of building such artifacts. The unfortunate thing is, we won't know what is the target platforms users of these application would be using. They could be using plain old bare metal servers or virtual machines. They could go slightly fancy and be using Kubernetes or other container based deployment platforms.

Here are some examples of types of artifacts one may think to provide:

- Docker images
- Helm chart
- Kustomize scripts
- RPMs (Centos Package System)
- DEBs (Ubuntu and Debian Package System)
- Linux executables
- Window executables
- Ansible scripts (maybe?)

We would also need to consider that the binaries could be deployed on various computer architectures such as 32 bit systems, 64 bit systems or arm systems.

For these artifacts, we would need to consider where those artifacts would be made available on. E.g. for docker images, should be put into Dockerhub? How frequent will the updates be for the docker images? What sort of version scheme would you be following? (follow app versioning? - but what if there is a need to change docker image base layers but not the application itself? How will it be handled?)

In some of the cases such as the helm chart and kustomize scripts - we may need to ensure that the configuration is setup in a flexible manner to ensure that users of these artifacts would be to customize the installation according to their requirements and architecture.

On top of that, if the application takes up a configuration file in order to alter and adjust the behaviour of the application, a significant amount of time and labour would be needed to document all of such behaviours down in order to inform users how the application can be modified to suite their user's needs.

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
- Level of logs that can be pulled from the application. In many companies, they would utilize some sort of centralized log collecting mechanism. This mechanism does have limits - these limits could be physical limits (storage space) or cost limits (storage of logs in the cloud platforms). By default, applications should run with minimal logs but there should be flags and configurations to allow debug of such logs in order to understand how the application work from the outside
- Formatting of logs. At times, some companies may have decided to go for json formatted log formatting to standardize it across applications/components. One reason to do so is to make it easier for their centralized logging system to parse such logs to do analysis on such logs
- Providing of distributed traces to understand the application further although this particular functionality is not too important
- In the case where we provide docker images to be used for deployment. It would be ideal to ensure the image is secure as per user's company's requirements. One way is to utilize small minimalistic base images: e.g. https://github.com/GoogleContainerTools/distroless or alpine images or slim images. Just do know that using these minimalistic images make it harder to build such artifacts (tooling/dependencies may be missing in such minimalistic images)
- In the case where the application is being updated, is there a smooth upgrade track that users can follow in order to safely upgrade the application without losing the data being stored in the application?
- As much as we would want users to continue using the application, there are cases where they would need to migrate off the tool. Maybe we would need to consider a way to export the data out of the tool?
- Our previous point, it's mentioned that it would be good to consider a capability to export data out of the tool where necessary. It might be good to also take into mind of maybe a feature/need where data can be imported into the application
- There are cases where the application that we may be building would provide a frontend. In general, we would just define the paths of such frontend sites without too much worry. However, there are cases where some users would want to put these applications behind proxy and would want to direct users to the application via a prefix path. To support this need, we would need to have a feature to allow users to define if the application would have some sort of prefix path for all the endpoints/frontend of the application

## Scalability

In some cases, some of the applications might turn out popular in the client's company. There might be a need to scale up or scale out the applications and it would be ideal if there are methodologies/steps/metrics to look out for in an attempt to scale it

Some points to think about:

- A guide on how to scale out application. If application is to be deployed on Kubernetes with a helm chart, one can utilize the HorizontalPodAutoscaler resource and define some default values that clients can kind of use
- It might be good to provide which metrics can be used/based on to scale out the application. We can scale an application based on its CPU usage or Memory usage. However, we can also go with something slightly more controversial metrics (e.g. number of items in a queue). However, the platform that hosts this needs to be able to support this capability.
- Does the application need to able to form a cluster if needed? Ideally, it would be best to avoid setting up cluster capability since that would make it really hard to maintain/test such applications. In my own opinion, clustering in application is reserved for stateful applications which doesn't apply for many applications

## Implemented Examples

Some of the above points have been found to be implemented in many of the open source projects out there.

- Jaeger Distributed Tracing project
  - Github Link: https://github.com/jaegertracing/jaeger
  - Documentation Page: https://www.jaegertracing.io/docs/1.23/getting-started/
- Elasticsearch project
  - Definitely a good example of what to follow when attempting to build applications which is aimed to be used by big companies