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

Meetup.com is a pretty nice site to setup meetups and sharings on technologies. The platform is pretty nice and easy to use when it comes to bookings but sometimes, the data provided by its web interface is not sufficient nor does it fit our use case. In this case, let's say you are trying to understand the trend of the number of people attending a meetup. To an organizer, an important thing to him/her is to understand what kind of actions would lead to higher turnups/registrations for a meetup.

There a few ways to solve this, but in this post, we'll be focusing mainly on the third and last option.

- [Using R and Python Scripts](#using-r-and-python-scripts)
- [Using free platform compute resources](#using-free-platform-compute-resources)
- [Using Serverless solutions](#using-serverless-solutions)

## Using R and Python Scripts

The first easier approach is to just have a python or R script which would then extract the values from the meetup api, which would then be able to pull the values in and then manipulate the values accordingly to be able generate the graphs that we need for analysis.

This solution is easy to start with although working with scripts makes it difficult to have such analysis done on demand. Seeing that this information would ideal to be made available at any time, having the solution this way would be that the one who generate the analysis needs to have access to a computer that has the R or Python runtimes available.

In the overall big picture, it would be best to move such scripts from running on a local computer which relies on a person manually needing to run it to running it on a server as an api. This would allow it to be consumed by chat applications or mobile applications that would make it easier obtaining the data for analysis.

## Using free platform compute resources

## Using Serverless solutions
