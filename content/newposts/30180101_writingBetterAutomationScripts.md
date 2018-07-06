+++
title = "Writing better automation scripts"
description = ""
tags = [
    "python",
]
date = "3018-03-14"
categories = [
    "python",
    "automation",
]
+++

Data engineering work usually serves to be fundamentally one of the important bits when it comes to report generation in the business. The act of connecting of understanding the data that goes through the business and the need to maintain all the scripts that handle the pulling and merging all of such data makes the job way harder than one can expect. You are not expected to just be a script junkie; you are expected to be an expert at your domain, understanding the different nuances and assumption each line of script imposes on the processing of such data.

Acquiring the initial set of requirements and writing such automation scripts is usually considered the easiest bit. The harder bits are maintainance, upgrades as well as ensuring that the scripts can be deployed to their respective users. If projects are prototyped rather than properly engineering, one can be pretty sure that there would be hiccoughs and plenty of engineering hours (fancy some late nights and overtime?) in order to ensure that the scripts are ready and running.

Let's go several scenarios on some of the more important bits to consider when doing automations at that stage.

## The Beginning

