+++
title = "Getting Meetup Stats with Google Cloud Functions"
description = ""
tags = [
    "python",
]
date = "3018-03-14"
categories = [
    "python",
    "automation",
    "serverless",
]
+++

Meetup.com is a pretty nice site to setup meetups and sharings on technologies. The platform is pretty nice and easy to use when it comes to bookings but sometimes, the data provided by its web interface is not sufficient nor does it fit our use case. In this case, let's say you are trying to understand the trend of the number of people attending a meetup. To an organizer, an important thing to him/her is to understand what kind of actions would lead to higher turnups/registrations for a meetup. So, by the end of this post, hopefully we would be able to have a pretty decently priced (free if possible) solution for an analytics solution which would only be called occasionally.

There a few ways to solve this, but in this post, we'll be focusing mainly on the third and last option.

- [Using R and Python Scripts](#using-r-and-python-scripts)
- [Using free platform compute resources](#using-free-platform-compute-resources)
- [Using Serverless solutions](#using-serverless-solutions)
    - [Creating a GCF Python app](#creating-a-gcf-python-app)
    - [Deploying GCF Python app via Google Cloud Repositories](#deploying-gcf-python-app-via-google-cloud-repositories)
    - [Setting up CI/CD pipelines via use of Google Cloud Builder](#setting-up-cicd-pipelines-via-use-of-google-cloud-builder)
    - [Integration with Slack Slash commands](#integration-with-slack-slash-commands)
- [List of links for TLDR](#list-of-links-for-tldr)

## Using R and Python Scripts

The first easier approach is to just have a python or R script which would then extract the values from the meetup api, which would then be able to pull the values in and then manipulate the values accordingly to be able generate the graphs that we need for analysis.

This solution is easy to start with although working with scripts makes it difficult to have such analysis done on demand. Seeing that this information would ideal to be made available at any time, having the solution this way would be that the one who generate the analysis needs to have access to a computer that has the R or Python runtimes available.

In the overall big picture, it would be best to move such scripts from running on a local computer which relies on a person manually needing to run it to running it on a server as an api. This would allow it to be consumed by chat applications or mobile applications that would make it easier obtaining the data for analysis.

## Using free platform compute resources

The Google platform provides several free resources for computation work. The list of free resources are available here for your convenience.

https://cloud.google.com/free/

An example of how this free computation can be done would be have the code be hosted on Google App Engine. API endpoints or cron jobs could be set up which could then be used my chat applications or mobile applications. The data could be processed and outputed into the various chat applications or data applications out there.

## Using Serverless solutions

A possible solution would be the usage of a serverless solution. In the Google Cloud Platform world, that would be the usage of Google Cloud Functions. It was recently announced that it would be in General Availability for Node.js 6 runtimes during the Google Cloud Next 2018 event. However, the interesting/exciting bit was the portion where the bit where it was mentioned that the python runtime is being supported in beta availability.

You can look to its release page for further information regarding this. Look to the July 24 release notes:  
https://cloud.google.com/functions/docs/release-notes

So with python support, we can now start to write python applications/scripts that can utilize this.

So, before getting started, we would want to wonder on why use this rather than using our compute engine or app engine etc. One strong reason is the nature of the application we are building here. In our case, we would running the script/application occasionally (sometimes only needing like a few seconds of compute each day). This would mean that it doesn't make sense to have the need to start a beefy compute engine service just to do that work. However, it would still be nice to be able to have an API be able available 24/7 which can be called in our convenience.

Seeing that Google Cloud Functions are priced in the 100ms interval (different amount of memory being used would lead to slight differences in pricing), this would give us tight granular control over the amount of money we spend on this, making this a cheaper and viable option for us to use especially for application that would only be occasionally used.

Also, it would be best if we can set up some sort of CI/CD pipeline for us to use when developing functions for the Google Cloud Functions tool. This would aid in deploying and make it way easier to get the application running on the platform.

To sum it up, this post could cover the following aspects:

- Covering a very basic Google Cloud Functions python app (api)
- Deploying it by relying on Google Cloud Repositories
- Setting up CI/CD pipelines via use of Google Cloud Builder
- Getting integration with Slack Slash commands

### Creating a GCF Python app

We can try a very simple python app just to get our feet wet with Google Cloud Function. There is a quickstart guide on the documentation page, but a copy of it is also available here for completeness sake.

Refer to the documentation here for a fuller explanation:  
https://cloud.google.com/functions/docs/tutorials/http

```python
def hello_get(request):
    """HTTP Cloud Function.
    Args:
        request (flask.Request): The request object.
    Returns:
        The response text, or any set of values that can be turned into a
        Response object using `make_response`
        <http://flask.pocoo.org/docs/0.12/api/#flask.Flask.make_response>.
    """
    return 'Hello, World!'
```

If you don't want to handle the console too much at this time as you're trying out, you can just simply copy it over to the editor that is already available on the cloud console for google cloud functions.

A `requirements.txt` file is not needed to get started for an initial deployment. However, it is vital for us to understand the limitations of the platform.

One of main gripes I have about the serverless platform (inclues AWS lambda as well) is that we have less control over the OS being used to run it. Let's say if we are building an application that relies on the ffmpeg binaries. That would be hard to run on AWS lambda because those binaries are not just readily available on the OS being used to run underneath powering AWS lambda. So, I'm not exactly too sure if this same limitation would affect Google Cloud Functions as well.

If one looks at how its solved, you can look no further that the `serverless` tool. The website is available here:  
https://serverless.com/

In order to resolve the problem of getting python dependencies in, the serverless tool would need to spin a docker container that would build up those dependencies (if needed). It would then zip it up and fly it over to the S3 bucket which would then be used to deploy the AWS Lambda function.

Luckily, there is no such need to do all that contorted mess in Google Cloud Functions. It was able to install particularly difficult libraries e.g. pandas with no significant issue (This was hard when I was trying it with AWS Lambda)

Alongside the python file in the main.py above, just add a `requirements.txt` and try it out.

```text
numpy
pandas
```

```python
import pandas as pd
import numpy as np

def hello_get(request):
    """HTTP Cloud Function.
    Args:
        request (flask.Request): The request object.
    Returns:
        The response text, or any set of values that can be turned into a
        Response object using `make_response`
        <http://flask.pocoo.org/docs/0.12/api/#flask.Flask.make_response>.
    """
    s = pd.Series([1,3,5,np.nan,6,8])
    return 'Hello, World!'
```

It was imported and run with no issues.

### Deploying GCF Python app via Google Cloud Repositories

random

### Setting up CI/CD pipelines via use of Google Cloud Builder

random

### Integration with Slack Slash commands

random

## List of links for TLDR

If the article above is too long to read, this section would provide the whole list of links to get started with using Google Cloud Functions and its family of tools to create a Slack slash command that can pull meetup stats on a Slack channel

- List of free simple Google Platform items that can be used (includes quota available etc)  
  https://cloud.google.com/free/
- Simple Python Application on Google Cloud Functions tool  
  https://cloud.google.com/functions/docs/tutorials/http
