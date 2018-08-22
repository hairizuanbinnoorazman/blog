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

## Using R and Python Scripts

The first easier approach is to just have a python or R script which would then extract the values from the meetup api, which would then be able to pull the values in and then manipulate the values accordingly to be able generate the graphs that we need for analysis.

This solution is easy to start with although working with scripts makes it difficult to have such analysis done on demand. Seeing that this information would ideal to be made available at any time, having the solution this way would be that the one who generate the analysis needs to have access to a computer that has the R or Python runtimes available.

In the overall big picture, it would be best to move such scripts from running on a local computer which relies on a person manually needing to run it to running it on a server as an api. This would allow it to be consumed by chat applications or mobile applications that would make it easier obtaining the data for analysis.

## Using free platform compute resources

The Google platform provides several free resources for computation work. The list of free resources are available here for your convenience.

https://cloud.google.com/free/

An example of how this free computation can be done would be have the code be hosted on Google App Engine. API endpoints or cron jobs could be set up which could then be used my chat applications or mobile applications. The data could be processed and outputed into the various chat applications or data applications out there.

## Using Serverless solutions

A possible solution would be the usage of serverless solution. In the Google Cloud Platform world, that would be the usage of the Google Cloud Functions tool. It was recently announced to be in General Availability for Node.js 6 runtimes during the Google Cloud Next 2018 event. However, the interesting/exciting bit was the portion where the bit where it was mentioned that the python runtime is being supported in beta availability.

You can look to its release page for further information regarding this. Look to the July 24 release notes:  
https://cloud.google.com/functions/docs/release-notes

So with python support, we can now start to write python applications/scripts that can utilize this.

So, before getting started, we would want to wonder on why use this rather than using our compute engine or app engine etc. One strong reason is the nature of the application we are building here. In our case, we would running the script/application occasionally (sometimes only needing like a few seconds of compute each day). This would mean that it doesn't make sense to have the need to start a beefy compute engine service just to do that work. However, it would still be nice to be able to have an API be able available 24/7 which can be called in our convenience.

Seeing that Google Cloud Functions are priced in the 100ms interval (different amount of memory being used would lead to slight differences in pricing), this would give us tight granular control over the amount of money we spend on this, making this a cheap and viable option for us to use.
