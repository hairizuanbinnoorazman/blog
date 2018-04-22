+++
title = "Creating a Slack command tool to create automated windows environments"
description = ""
tags = [
    "golang",
]
date = "3018-03-28"
categories = [
    "golang",
    "tool",
]
+++

Let's imagine a scenario where we don't have any browser testing plans nor any browser that is on a windows laptop. All the developers are mac users and the website being developed requires IE support. How should we handle this in an elegant manner?

Oh, let's add an additional challenge; we only use GCP because reasons...

One way to resolve is to create a Windows Server on the platform via a Virtual Machine isntance. This would allow us to utilize the server and then test the website on it. However, the setting up of such a virtual machine is kind of trivial -> it takes roughly 10-15 minutes of clicking through and accessing the GCP console, set the settings for the window server, waiting for the windows server to run, setting a new password and user for the machine so that we can have RDP access etc...

We can try to go through all that, or we can attemmpt to automate some parts of the creating such a server. (This is more of a for fun project rather than something really productive)

# Defining the specs

- We shall make a Slack command that would call a serverless application via a HTTP interface which would then call the GCP API to create the virtual machine. Name the machine sth that starts with `test` accompanied by some hash.
- After waiting a while for the VM to load, create a new user and password and pass along to the slack channel.
- At the end of the day at 6pm, we would delete all of such test instances.
- To prevent abuse of the command, the command will first check if there are such instances and will not execute. However, a `force` parameter should be able to overwrite such settings if needed.