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
image = ""
+++

AWS Lambda is an interesting piece of product that AWS released in recent years. Rather than
programming your usual server backends and frontends, instead we write up functions and let the infrastructure
handle the scaling and deploying of those said functions. These allows the creation of more light weight 
services, (e.g. uploading of docs) which originally require one to extend the functionality of an app in some 
weird odd way. Now instead, we can just write a function that can be used across various different applications
(uploading a document on a scheduled basis should be the same across all apps right?)

However, if one is to write for those said AWS lambda functions, it gets complicated really quickly. In 
order to utilize the full ecosystem, you would need to write cloud formation templates to spin up the 
required architecture and permission systems to get the whole functionality working.

# Using Serverless Framework for serverless applications

This is where the serverless framework kind of comes in. Here's a link to their website:

https://serverless.com/

The nice thing is that the framework works across multiple platforms (a caveat to take note here is that
)