+++
title = "Trying Ansible"
description = "Using ansible in order to deploy a bunch of binaries onto a single virtual machine"
tags = [
    "ansible",
    "devops",
]
date = "3018-03-14"
categories = [
    "ansible",
    "devops",
]
+++

Let's set the scenario where we want to deploy a bunch of services to a server.

- A web service. This would be a web service build via go. Nginx and apache are not needed to forward traffic to them. It would be possible to send traffic immediately to it
- A queue service. This is so that in the case where traffic gets too big for the whole web binary to handle it, we can split the services apart with no apparent problem
- A database service. This is to store our stateful data inside
- Multiple task services. Same as mentioned in the queue service. If necessary, this would be to allow us to send the task service to another server
