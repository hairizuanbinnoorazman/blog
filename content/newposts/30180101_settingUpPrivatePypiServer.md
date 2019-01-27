+++
title = "Setting up a Private Pypi Server"
description = "Setting up a Private Pypi Server using Docker on Google Cloud Platform"
tags = [
    "google-cloud",
]
date = "3018-05-02"
categories = [
    "google-cloud",
]
+++

As one writes several python applications to be targeted on the Google Cloud Functions platform, it becomes increasingly obvious to pull out the more common bits of code out into its own library. Let's have an example on the reason for this.

Let's say you have a small function integrates with Slack APIs. It takes in json blobs and manipulate such blobs before forwarding it towards Slack. When you do your first integration with Slack with another service, it seems pretty simple and straightforward; just refer to the json being used to that service. However, after doing the integration for the fifth time, it points to the need for some sort of common code that can be used to build up the structure of json blob to be sent to the service. We need some sort of client package to do this.

There are a few benefits for having a client package; the consumers of said services does not need to look to deep of what inputs that are used to sent over. They can just import the client library and begin to use said service with relative ease as compared to the alternatives of requiring to build the clients.

## Ways to have client packages

In python, there are several ways to import packages. The most common way is to have the import packages from the public python repositories but that would only be for public packages. If one wants to have a private python packages, alternatives are to put it on pypi packages server (private), utilize private git repositories (you can install python packages from a git repository without building the python package) or hosting the python package on your pypi-server setup.

For this post, it'll explore on how to set up pyivate python package hosting with your own pypi-server setup
