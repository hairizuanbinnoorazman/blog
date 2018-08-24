+++
title = "Getting Meetup Stats with Google Cloud Functions"
description = "Getting Meetup Stats with Google Cloud Functions"
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
- [Getting the full picture from more complete code](#getting-the-full-picture-from-more-complete-code)
- [List of links for TLDR](#list-of-links-for-tldr)
    - [Google Cloud Documentation Links](#google-cloud-documentation-links)
    - [Slack Documentation Links](#slack-documentation-links)
    - [Other Links](#other-links)

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

It should be easy to import and run with no issues

### Deploying GCF Python app via Google Cloud Repositories

There are various ways to deploy a Google Cloud Function. At the moment, one can just type the code straight into its editor, or put a zip file either into Google Cloud Functions directly or via Google Cloud Storage. At the last alternative way would be to set it up with Google Cloud Source Repositories.

![gcf_sources](/20180824_meetupStatsWithGoogleCloudFunctions/gcf_sources.png)

The Google Cloud Source Repositories is an interesting approach. Rather than having to zip up files and folders and ship it into S3 etc, one can just point the Google Cloud Function to consume it from the repo directly. The nice bit is that one can easily set up Google Cloud Source Repositories to mirror off more traditional places of hosting the codebase, e.g. Github or Bitbucket. The option allows code to be mirrored over.

![gcf_sources](/20180824_meetupStatsWithGoogleCloudFunctions/gcf_repo_settings.png)

It is not exactly necessary to have a bunch of pictures to show how to setup mirroring in Google Cloud Source Repositories. The forms in the tool is quite easy and intuitive to understand; one can just click through without going through any documentation to set this workflow up.

We can then deploy code from a specific branch, tag and even the folder. It is possible to specify all of such details which makes this a pretty flexible and easy solution. Refer to the link below for more details on this:

https://cloud.google.com/sdk/gcloud/reference/functions/deploy

### Setting up CI/CD pipelines via use of Google Cloud Builder

Seeing that it is possible to just use the `gcloud` cli tool to be able to deploy the solution, this would mean that we can replicate that same effort via using the Google Cloud Builder tool.

The Google Cloud Builder is kind of Google's answer to build systems at scale. Just think of it simply of how a company would evolve when they are using their build systems:

- Developer starts of with using Jenkins as it is standard build tool in the industry.
- As time goes by, more builds are needed on Jenkins. It is essentially to have Jenkins work in a master and slave configuration, where the master would allocate build jobs to the slaves which wouold build the apps for deployment
- Too many configurations, libraries, and junk put into Jenkins; build system evolve to utilize docker to build docker containers in order to encapsulte the different app and its dependencies from each other.

Google Cloud Build is kind of the last step; a scalable build solution which is managed by the platform. One would need to use a `cloudbuild.yaml` file in order to specify the different steps needed to build the applications which can then be sent to the target platform.

For example, for Google Cloud Functions, the following configuration is helpful:

```yaml
steps:
  - name: "gcr.io/cloud-builders/gcloud"
    args:
      [
        "beta",
        "functions",
        "deploy",
        "{function name}",
        "--region=asia-northeast1",
        "--source=https://source.developers.google.com/projects/{projectid}/repos/{repo name}/moveable-aliases/{branch name}/paths/{path name}",
        "--trigger-http",
```

Some of the weird things while setting up CI/CD with Google Cloud Build:

- If command is called without using region: It would redeploy but to a different region (So its necessary to specify this here). The assumption here is that it is using some sort of default region.
- If command is called without source, it would redeploy but the source repo would not change. It just seem to redeploy the same copy of the codebase
- The general assumption here is that the params specified here needs to be used such that if you were to do an initial deploy. There is no sense of "previous state" of the application being deployed before.
- Permissions is big pain point here - no all permissions required are mentioned in the documentation. To get it working, the minimum set of permissions needed are:
  - Cloud Build Service Account
  - Cloud Function Developer
  - Cloud Function Service Agent
- (Continuing on permission) This is on the assumption that the we are deploying Google Cloud Functions via usage of the source repositories in Google Source Repositories. If we are to do it by sending a zip over Google Cloud Storage, it might be nceessary to see if we need to add permissions to read and write to Google Cloud Storage here.

![gcf_sources](/20180824_meetupStatsWithGoogleCloudFunctions/cloud_builder_permissions.png)

### Integration with Slack Slash commands

So, we have a working http api that we can curl with. How can we make it really accessible anytime. One way would be to link it up with Slack. With Slack, there is an interesting capability to have slash commands which would then allow it to be integrate with other external APIs. The Slack slash command would call a post request to hit against the API specified with a form body request. The form body request would contain all kinds of information including which channel the slack command is called from etc

As usual before we get started, we need to handle permissions; so go to the following url: https://api.slack.com/apps. After which, activate the following features:

- Incoming webhooks
- Slash commands
- Permissions (Some of the features will be auto-turned on when the feature is activated)
  - Access information about user's public channels
  - Send messages as bot
  - Send messages as service
  - Post to specific channels
  - Upload and modify files
  - Add Slash commands

![gcf_sources](/20180824_meetupStatsWithGoogleCloudFunctions/slack_features.png)

![gcf_sources](/20180824_meetupStatsWithGoogleCloudFunctions/slack_permissions.png)

Once we have that, we would be able to interact with Slack's API.

The following is a simple python function that sends a message to a channel on Slack

```python
def send_text_to_channel(slack_token, slack_channel_id, text):
    upload_url = "https://slack.com/api/chat.postMessage"
    data = {"token": slack_token,
            "channel": slack_channel_id,
            "text": text}

    response = requests.post(upload_url, params=data)

    if response.status_code != 200:
        raise Exception(json.dumps({"error": "Unable to send text"}))
```

One can potentially just rely on external 3rd party slack library but seeing that we are only going to use a subset of features, it wouldn't make too much sense to hunt for a good library to use Slack

## Getting the full picture from more complete code

To get a fuller picture of how the whole thing works, the full source code on this is available publically here: https://github.com/hairizuanbinnoorazman/meetup-stats

## List of links for TLDR

If the article above is too long to read, this section would provide the whole list of links to get started with using Google Cloud Functions and its family of tools to create a Slack slash command that can pull meetup stats on a Slack channel.

### Google Cloud Documentation Links

- List of free simple Google Platform items that can be used (includes quota available etc)  
  https://cloud.google.com/free/
- Simple Python Application on Google Cloud Functions tool  
  https://cloud.google.com/functions/docs/tutorials/http
- Google Cloud Functions Pricing  
  https://cloud.google.com/functions/pricing
- Deploying a Google Cloud Functions via gcloud CLI  
  https://cloud.google.com/sdk/gcloud/reference/functions/deploy
- Google Cloud Builder Documentation  
  https://cloud.google.com/cloud-build/docs/

### Slack Documentation Links

- Slack API  
  https://api.slack.com/apps
- Slack Slash Commands Documentation  
  https://api.slack.com/slash-commands
- Slack Incoming Webhook Documentation
  https://api.slack.com/incoming-webhooks

### Other Links

- Github Repository to the working code for this  
  https://github.com/hairizuanbinnoorazman/meetup-stats
- [Link](/posts/20180729_googleNext2018) to a summary of some videos from Google Cloud Next (non-exhaustive)
