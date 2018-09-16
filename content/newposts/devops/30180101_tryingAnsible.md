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

## Installing ansible

Ansible is available as an installable package via the various flovours of linux. Since I'm mostly on debian linux, I'll just provide instructions for installing ansible via `apt`

```bash
apt install ansible
```

It is possible for one to install ansible via python. Note that the ansible tooling is mainly using python 2 and not python 3. I previously attempted to use ansible 2.2 with python 3 and it ended in a disaster (I kind of deserve it for not reading the documentation here)

Also, one can just have python on the computer and install it via pip installs. It should still work as expected.

```bash
pip install ansible
```

## Basic configuration

```yaml
- name: apply common configuration to all nodes
  hosts: localhost
  tasks:
    - name: Install git
      apt: name=git
```

All of the ansible configuration is put into a single file.
