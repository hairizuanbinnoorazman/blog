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

There is an interesting movement going about in companies, the movement to have infrastructure of a company be described via code. Using code, we can describe the services a company uses, which can then be used to start and run the required services without required people who have expertise in server management and installing of all these packages.

If you take a step back and look at the grand scheme of development work in general:

Development work -> Contionuos Integration (Automatic Building of Application assets) -> Continuous Deployment (Automatic Deployment of application to production)

Ansible would kind of fall as a tool that can be used to deploy assets to various environments. Potentially, one can use scripts to control such environments but for a more organized effort to do so, one can rely on ansible scripts to deploy the applications. There are many other applications out there that assist with that effort including spinnaker, terraform, chef, puppet; but ansible is just one of such applications that can be used for this.

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

Look to the ansible documentation for more details on how to get installation done on the servers/computers

## Basic configuration

```yaml
- name: Installing git
  hosts: localhost
  apt:
    name: "{{ packages }}"
    update_cache: yes
  vars:
    packages:
      - git
```

All of the ansible configuration can put into a single file. For basic scenarios, that would be fine but for more complicated scenarios, it might be more advisable to actually follow some of the recommended folder structures that the website recommends: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html. The best practises is how the ansible uses the folder names to intepret the various playbooks and variables names used.

## Scenario

- A web service. This would be a web service build via go. Nginx and apache are not needed to forward traffic to them. It would be possible to send traffic immediately to it
- A queue service. This is so that in the case where traffic gets too big for the whole web binary to handle it, we can split the services apart with no apparent problem
- A database service. This is to store our stateful data inside
- Multiple task services. Same as mentioned in the queue service. If necessary, this would be to allow us to send the task service to another server

In our case, let's install a simple web application service. This would be accompanied with a NATS queue service and a MySQL database. At the same time, let's have several task workers to pick up items from queue. The sample applications will be written in Go for our case.
