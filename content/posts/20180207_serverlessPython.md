+++
title = "Serverless Python"
description = ""
tags = [
    "serverless",
    "python",
]
date = "3000-01-20"
categories = [
    "serverless",
    "python",
]
+++

AWS Lambda is an interesting piece of product that AWS released in recent years. Rather than programming your usual server backends and frontends, instead we write up functions and let the infrastructure handle the scaling and deploying of those said functions. These allows the creation of more light weight services, (e.g. uploading of docs) which originally require one to extend the functionality of an app in some weird odd way. Now instead, we can just write a function that can be used across various different applications (uploading a document on a scheduled basis should be the same across all apps right?)

However, if one is to write for those said AWS lambda functions, it gets complicated really quickly. In order to utilize the full ecosystem, you would need to write cloud formation templates to spin up the required architecture and permission systems to get the whole functionality working.

## Using Serverless Framework for serverless applications

This is where the serverless framework kind of comes in. Here's a link to their website:

https://serverless.com/

The nice thing is that the framework works across multiple platforms (a caveat to take note here is that using the serverless framework doesn't mean that the same set of features are available across all of the cloud platforms. Each of the cloud platforms provides their own set of features; the serverless framework only serve to put a thin layer on top of this to make development and deployment an easy experience.)

## Installing the tools

Before starting, it would be good to ensure that you have the following tools installed; namely `Serverless` and `pipenv`. I will be describing more about each of them below. And also, it would be good to install `Docker` as well.

### Installing Serverless

The `Serverless` cli tools can be installed by just following the instructions on the serverless web page. Nothing too fancy about that, it only involves getting the cli into machine. Simply follow:

Refer to the following link for more details: https://serverless.com/framework/docs/providers/aws/guide/installation/

```bash
npm install -g serverless
```

By installing it globally, we can now use it easily across any folder as we please.

### Installing pipenv

Another tool mentioned above as well is `pipenv`. Since in this blog post, we will be developing using python, we might want to look into the good approaches of using python. There are many advantages of using this tool - you can see the list of advantages here on the website: https://docs.pipenv.org/. 

One reason for myself using the tool is that it ensures that the right dependencies as well as the right underlying dependencies are installed for the application. This may not seem too obvious at first or second glance but when you've been playing around with some of those massive python libraries that import a whole bunch of other python dependencies, it always seem much easier to break the build due to some problematic underlying dependencies that one your own app's dependency depend on. (#dependenception anyone?)

It involves relying on two files, a lock file and a toml file (`Pipfile` and `Pipfile.lock` that states all the required dependencies (kind of similar to the node's ecosystem of installing dependencies and locking it as well.)

## Starting development work

We can start this using serverless by running the following command here:

```bash
serverless create --template aws-python3
```
This would create all of required templates files like 


