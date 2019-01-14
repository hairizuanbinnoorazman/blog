+++
title = "Devops Tools with Google Cloud Platform"
description = "Using devops tooling to make it easier to deploy applications to Cloud Platforms"
tags = [
    "google-cloud",
]
date = "3018-05-02"
categories = [
    "google-cloud",
]
+++

There are various tooling out there to make deployment of applications easier. Some tools are used in order to help developers and organizations attempt to reach the "12 factor app" standard of applications which are set of applications that are explicitly designed to be able to scale where needed.

Nowadays, many people turn to docker in an attempt to solve some of the goals in 12 factor app designs. (e.g. Using `dockerfiles` which would declaratively mention all dependencies needed by the application and its operations.). However, let's say that we are restricted from using containers and if we were to rely on only virtual machines in public cloud. What could we depend on?

Let's go through several tools that can help developers achieve this goal:

1. Ansible. A tool that allows developers to declarively configure a server more easily. The ansible allows one to declaratively/implicitly install packages, add configurations files via use of templates files and run admin commands. It is possible to actually run bash scripts to run get all of such settings into the server but shell scripts aren't easy to read and debug and program. It is easier to write scripts but with ansible, the tool comes with a whole bunch of functionality that allows one to declare the require actions to install the required software onto the server.
2. Terraform. A tool that allows developers to create their needed infrastructure on a public cloud. (There are other uses to this tool, but generally, it is used to bootstrap/maintain infrastructure). With the Terraform tool, it allows one to maintain a set of files which describes their application infrastructure. The tool would take the responsibility to ensure that the actual infrastructure matches what is being described in those files.
3. Packer. A tool that creates custom images. When trying to scale applications on the cloud, it is required to create some sort of server template that the cloud can use to create multiple copies of the application for horizontal scalability. In order to help create the server template in a reproducible manner, we can use scripts to create the images (rather than setting up the servers manually and then setting it to be a template that the cloud vendor can use to support scaling needs)
