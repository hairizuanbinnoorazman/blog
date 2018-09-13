+++
title = "Attempting to setup Kubernetes on Ubuntu VMs"
description = "Kubernetes on Ubuntu Virtual Machines via lxc and snap"
tags = [
    "kubernetes",
]
date = "3018-03-14"
categories = [
    "kubernetes",
]
+++

This post details steps to trying out Kubernetes in a bare Google Virtual Machine (but the following steps should work for most Debian/Ubuntu virtual machines). This deploys a single node Kubernetes cluster (evidently don't think of using this for production)

`lxc` is the client to lxd which runs linux containers. https://en.wikipedia.org/wiki/LXC. The conjure-up tool would install kubernetes via linux commands

## Installing snap, lxc and conjure-up

- We would be testing to deploy a Kubernetes Cluster on a single node using the `snap` utility. These are the set of commands to do it.
- We would install `snap` via `snapd`. Then, using snap, we can then install `lxd`, `kubectl` and `conjure-up`
- We would finally then add our own username to the lxd groups so that we don't need to use sudo when lxd/lxc commands.
- We would use lxc to communicate to lxd

```bash
sudo apt update
sudo apt -y install snapd
sudo snap install lxd
sudo snap install kubectl --classic
sudo snap install conjure-up --classic
sudo usermod --append --groups lxd {{ NAME }}
```

## Deploy a Kubernetes cluster via conjure-up

- We would first initialize the set of environment for the linux containers to live in; using the init command, we would start up the network as well as storage. One thing to note is that for the snap install Kubernetes command, we are only able `dir` type of storage. Other storage will cause the deployment to completely halt.

```bash
# Most defaults work ok except for storage. Storage, choose dir type
lxd init

# Questions and choices
# Would you like to use LXD clustering? (yes/no) [default=no]: no
# Do you want to configure a new storage pool? (yes/no) [default=yes]:
# Name of the new storage pool [default=default]:
# Name of the storage backend to use (btrfs, ceph, dir, lvm) [default=btrfs]: dir
# Would you like to connect to a MAAS server? (yes/no) [default=no]:
# Would you like to create a new local network bridge? (yes/no) [default=yes]:
# What should the new bridge be called? [default=lxdbr0]:
# What IPv4 address should be used? (CIDR subnet notation, “auto” or “none”) [default=auto]:
# What IPv6 address should be used? (CIDR subnet notation, “auto” or “none”) [default=auto]: none
# Would you like LXD to be available over the network? (yes/no) [default=no]:
# Would you like stale cached images to be updated automatically? (yes/no) [default=yes]
# Would you like a YAML "lxd init" preseed to be printed? (yes/no) [default=no]:

conjure-up kubernetes

# Questions and choices
# What kind of kubernetes installation: kubernetes-core
# Where to install: localhost
# Storage pool: default
# Network bridge: lxdbr0
# Network: flannel
```

The `conjure-up` command takes a while to run. It depends on virtual machine's network. The faster the network, the faster this can be deployed. After waiting for a while, the kubernetes

## Testing out kubernetes cluster

We would try to run some `nginx` containers as they one of the simplest to run. With the nginx containers, we should able to hit the service on port 80 and it should return us a default nginx page.

```bash
kubectl run --image nginx lol
kubectl run --image nginx lol1
kubectl expose deployments lol --type NodePort --port 80
kubectl exec -it {{ lol1-pod-name }} /bin/bash
```

```bash
apt update
apt install curl
curl {{ ip address of lol }}:80
```

Notes:

Enable forwarding on your linux box:
Allow specific (or all of it) packets to traverse your router
As someone stated, as netfilter is a stateless firewall, allow traffic for already established connections
Change the source address on packets going out to the internet

```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -A FORWARD -i wlan1 -o wlan0 -j ACCEPT
iptables -A FORWARD -i wlan0 -o wlan1 -m state --state ESTABLISHED,RELATED \
            -j ACCEPT
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
```
