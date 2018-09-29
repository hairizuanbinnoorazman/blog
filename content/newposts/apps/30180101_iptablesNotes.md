+++
title = "Gophercon summaries 2018"
description = ""
tags = [
    "go",
]
date = "3018-03-14"
categories = [
    "go",
]
+++

```bash
apt install iptables
apt install bridge-utils
```

The following code assumes the following:

- host machine 1: ip-address - 192.168.1.10 - br0
- lxc machine in host machine 1: 10.0.3.76
- host machine 2: ip-address2 - 192.168.1.112

```bash
# Flush ip tables and remove records
iptables -F
iptables -t nat -F

# Allow access to all
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT

# To view current state of iptables
iptables -t nat -L -n -v

# Masquerade is to allow to route traffic without disrupting the original traffic.
# This post routing command is to allow traffic from lxc containers to go to the internet just fine
# Using -A is append to bottom, Using -I means add to the front of the list
iptables -t nat -A POSTROUTING -s 10.0.3.0/24 -o br0 -j MASQUERADE

# Following setting needed to do forwarding of traffic
# /etc/systcl.conf => net.ipv4.ip_forward = 1
# OR run this to have immediate effect:
# echo 1 > /proc/sys/net/ipv4/ip_forward

# DNAT is used when an external services intends to talk to an internal service (in this case, an lxc container)
# d - destination ip address (The address that would hit the machien - usually the eth0 network interface)
# d - destination port
iptables -t nat -A PREROUTING -p tcp -i br0 -d 192.168.1.10 --dport 8080 -j DNAT --to 10.0.3.76:80

iptables -t nat -I PREROUTING -p tcp -i eth0 -d 10.128.0.3 --dport 80 -j DNAT --to 172.18.0.1:8080
iptables -t nat -I PREROUTING -p tcp -i eth0 -j DNAT --to 172.18.0.1:8080
iptables -t nat -D PREROUTING 1
```

Run in the lxc container

```bash

```
