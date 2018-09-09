+++
title = "Using AWS Lambda for Data Science Projects and Automations 1"
description = "AWS Lambda for Data Science Projects - A thought experiment"
tags = [
    "python",
    "serverless",
]
date = "2017-12-20"
categories = [
    "python",
    "serverless",
]
+++

## A thought experiment

Let's say there was this one day during your usual work hours where you are tasked to handle some data transformations between your data sources. The data source is csv file generated from backend systems and is provided on the hourly basis. These data sources are to be analyzed as soon as possible and the insights are to be relayed to the marketing and business intelligence teams. How should we handle this? (Of course we should aim for as cheap a solution as possible)

If we are to do this task normally, we might think of spinning up a single AWS EC2 Compute Instance. To make comparisons fair, let's say the memory requirements for this compute is 1GB of memory. If you were to check the cost of this, it would be:

Maintaining 1GB EC2 Compute Instance on Demand as of 20 December 2017: $8.50

However, let's say we construct a varying solution instead; we rely on AWS Lambda. If we are to calculate a pretty bad estimate where each time the transformation runs, it takes 5 mins on 1GB of memory and assuming that we don't use up the free 1 million requests that AWS grants to all of its users (as of 20 December 2017). The price of that would go as follows:

As of 20 December 2017, maintaining 1GB Memory for AWS Lambda, 5 minutes each time to transform data, no free requests available. The calculations can be condensed below:

- Size of AWS Lambda: 1GB Memory
- Length of Function: 5 minutes
- Number of times to run per day: 24
- No of days in a month: 30
- Cost of AWS Lambda for the memory specified: $0.000001667 per 100ms

_This numbers are just estimate to quickly compare its cost effectiveness. By default, initial usage of AWS Lambda is free for the amount of time used to run the function but we are not taking that into account for now._

Estimated Cost: **$3.60**

The price is kind of comparable if you use the following scenario but let's instead say that the workload only needs to run once a day. The cost of running such a compute drops to mere cents. This makes running the script on a EC2 instance for the whole month so much more expensive.

However, the numbers above are just mere estimates, we would still need to run actual experiments to actually compare the cost effectiveness between the two solutions (Hosting a data science automation on EC2 vs AWS Lambda).

## Comparing approaches

Instead of just looking at cost alone, let's take a look at other things that should be considered when architecting a solution.

### Ease of getting resources to understand deploying to EC2 or AWS Lambda

With a quick search on Google, you will find that is is slightly harder to find applications/solutions done as compared to the alternative. This is understandable; the method done on EC2 is pretty common; the approach would be install the dependencies and then rely on cron to handle the running of the scripts.However, it is slightly harder to find stuff for AWS Lambda; the approach is newer (actually its already a few years old) and not many people are immediately introduced to such a way of doing things. Programming books still rely on using servers or managed web platforms (Heroku?) to deploy the applications.

### Operating the solution on EC2 or AWS Lambda

This might be tough the conclude properly. It is easier to get some of the operation effort for AWS Lambda; it comes out of the box with AWS Cloud Logs and Metrics. At the same time, the solution can be relatively standalone and it makes it easy to scale out the solution if needed.For EC2, unfortunately, it is a lot harder to do so. Most of the tasks to make it operationally easier to handle requires the developer to do so. Some of the tasks like exposing your logs to a centralized logging system, hooking metrics to it, ensuring you have a immutable image when deploying a solution (i believe that this is really vital when it comes to deploying services to the cloud) etc. The tooling is there and available but it would be really hard for those who just started scripting to go and do such tasks.

### Development ease/difficulty

AWS Lambda is a managed platform. And with all managed platforms, you cannot really install whatever you like into it. If you read the AWS Lambda documentation and plenty of stack overflow posts, you would have gotten a hint of how to do this: We install the libraries and package it up together with our code to the AWS Lambda. (It sounds easier than what it actually is)On the other hand, installing packages on your servers/containers is a piece of cake but this also meant that if there was any package management issue that causes the server/container to be unstable, that would be your problem.

## Let's Code...

...but not in this post. This post is plenty long enough. The next post in this set of serverless blog posts that I will be covering would cover attempts to code and deploy code on AWS Lambda or other serverless platforms.
