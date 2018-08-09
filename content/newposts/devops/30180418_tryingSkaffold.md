+++
title = "Trying out skaffold"
description = "Trying out skaffold"
tags = [
    "golang",
    "kubernetes",
]
date = "2018-08-10"
categories = [
    "golang",
    "devops",
    "kubernetes",
]
+++

When developing application that are meant to be deployed to the Kubernetes platform, it involves a bunch of steps on top of your usual local development work:

- Writing a Dockerfile to package the application (Multi stage applications are optional here - useful for compiled based languages)
- Build and tagging the docker image of the application with the target repository
- Either use `kubectl` commands or use kubernetes config resource files to define the resources required for deploying the applications. Use those commands/configurations to define the resources on the staging/production application
- Repeat the process for each update of the application (Repeat second point onwards)

As you see from above, it starts to be pain to do so after each iteration of the application development. The building of the docker containers process as well as the applying of the new images to each cluster, (sometimes with slightly changed configuration files) - the kubernetes secret and config files can change across different environments.

One can choose to use bash scripts to handle the issue but there is another potential tool that can be used for this: `skaffold`

The skaffold tool can be found here:  
https://github.com/GoogleContainerTools/skaffold

This tool is now way easier to use especially since Docker kind of packages Kubernetes along with Docker (It's an optional installation but still it way easier as compared to find tools out there in the market and getting them running etc)

The tool provides several interesting features that I kind of want to highlight:

- Hot reloading of the application. On save of your application code, the `skaffold dev` command will rebuild your application. It will only monitor changes there were specified within the `skaffold.yaml` file; this would be directories of your Docker context as well as the kubernetes manifest files
- Allowing multiple **profiles** to be stored for use. This allow one to switch between the different types of deployments from the same command line. Like I can easily be developing locally and once I'm happy, I can run something like `skaffold run -p stag` to set the required images into staging environment or even qa environment etc. In the case where locally, I need to play around with only mocked services, I could then easily send my code over to a cluster that is more relatively more "setup" with additional services to properly test the code.
- Switch tools being used for building the docker containers. Most of the time, I could use my local computer to build the application but sometimes, it would be nice to kind of rely on an external build system that would kind of build the application for me. This would matter more if the application relies on a lot of packages and I would need a clean build (with zero cache usage); it would help for the container builder to be in an environment where the packages can be downloaded at high speeds. (e.g. on cloud infrastructure)

Here is a sample working application and skaffold configuration for local environment:  
https://github.com/hairizuanbinnoorazman/kubeapps/tree/master/basicSkaffold
