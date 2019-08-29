+++
title = "SSH configurations for going into Google Cloud Instances"
description = "SSH into Google Cloud Instances that do not have a Public IP address by altering ssh configuration"
tags = [
    "google-cloud",
]
date = "2019-08-01"
categories = [
    "google-cloud",
]
+++

A classic move to reduce the attack surface of Google Cloud Instances is follow the advice below:

- If service on instance don't need Public IPs, don't attach Public IPs to such instances
- If instance requires Public IPs, ensure that only specific ports that are required are exposed. Clamp down on the rest of the ports and ensure no ingress on them

With these basic principles, it would be simple to think how these would eventually lead to an architecture where users access the instances via a bastion host. A bastion host is a instance that would allow user to ssh in from the "outside" world. The more critical instances would linked together in a private network that is unaccessible from the outside (except for load balancers to receive traffic etc).

Here are some of the better explained articles on the topic:

https://cloud.google.com/solutions/connecting-securely#bastion
https://en.wikipedia.org/wiki/Bastion_host

However, if we setup the architecture this way, how can we ssh into private instances from the outside world? It would be unwise to first ssh into the bastion host and then have our private keys there so that we can ssh further. Doing that wouldn't make sense; it wouldn't increase security but instead, just made it worst.

So, one of the better ways to do this is to actually use a configuration called `ProxyCommand` that is part of the ssh utility.

Let's take an example. Let's say we have 2 instances:

- Instance 1:
  - Public IP: 70.70.70.70
  - Private IP: 10.0.0.1
- Instance 2:
  - Private IP: 10.0.0.2

In order to ssh in Instance 2 from the outside world (e.g. my own local computer), I can run the command as follows:

```bash
ssh -o ProxyCommand="ssh -W %h:%p 70.70.70.70" 10.0.0.2
```

With the command, we are ssh-ing into the Instance 2 by jumping through Instance 1. (So if Instance 1 goes down, our ssh session would end as well)

But rather than typing the above command over and over again, we might as well set the folllowing in the ssh configuration file (~/.ssh/config)

```
Host Bastion
    HostName 70.70.70.70
    Port 22
    User AdminUser
    IdentityFile ~/.ssh/id_rsa

Host AppServer
    HostName 10.0.0.2
    Port 22
    User AdminUser
    IdentityFile ~/.ssh/id_rsa
    ProxyCommand ssh -W %h:%p Bastion
```

So, if you type:

```
ssh AppServer
```

It would be get you into the server without too much effort from your end to remember what params to add to the ssh command
