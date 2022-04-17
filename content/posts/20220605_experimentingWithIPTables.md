+++
title = "Experimenting with IP Tables"
description = "Understanding IP Tables"
tags = [
    "devops",
    "google-cloud",
]
date = "2022-06-05"
categories = [
    "devops",
    "google-cloud",
]
+++

While playing around with container technologies such as docker and kubernetes, one critical component that kind of comes up over and over again is the whole portion about managing network connections to the containers. If we are to just take an example of Kubernetes - the networking stack is handled by technologies that would interface with CNI as well kube proxy. In this post, we'll be focusing on the linux feature that kube proxy kind of rely on (one of the modes that it runs on) which is IP Tables.

## Introduction

According to wikipedia: "iptables is a user-space utility program that allows a system administrator to configure the IP packet filter rules of the Linux kernel firewall". 

There are multiple tables of concern with IPTables but we generally would only concern ourselves with 2 tables (NAT and FILTER). There are 5 different tables to manage but the rest of them are for more specific use cases. Refer to the following link for details https://wiki.archlinux.org/title/iptables:
- NAT
- FILTER
- RAW
- MANGLE
- SECURITY


```bash
iptables -L -v
```

```bash
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
```

```bash
iptables -A INPUT -s "<IP ADDRESS>" -j DROP
```

Refer to the following reference: https://web.mit.edu/rhel-doc/4/RH-DOCS/rhel-rg-en-4/s1-iptables-options.html

## Blocking access to nginx

```bash
iptables -A INPUT -p tcp --dport 80 -s X.X.X.X -j DROP
```

Block port 80 for source ip X.X.X.X by dropping the network packets for it. Alternatively, we can set it to "reject" the packets

```bash
iptables -A INPUT -p tcp --dport 80 -s X.X.X.X -j REJECT
```

## Redirect port

```bash
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j REDIRECT --to-port 80
```

From the following link: https://askubuntu.com/questions/444729/redirect-port-80-to-8080-and-make-it-work-on-local-machine  
Packets meant for loopback interface don't exactly go through PREROUTING chain

So, from external, it would work, but from inside, not really.

We would need to add the following command to make it with localhost:

```bash
iptables -t nat -A OUTPUT -o lo -p tcp --dport 8080 -j REDIRECT --to-port 80
```

## Cleanup

```bash
iptables -F
iptables -t nat -F
```

## After install docker 

(Still researching - do not use as reference)

Installing docker

```bash
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
```

```bash
iptables -nvL
```

```bash
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target                      prot opt in     out     source               destination         
    0     0 DOCKER-USER                 all  --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-ISOLATION-STAGE-1    all  --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT                      all  --  *      docker0  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 DOCKER                      all  --  *      docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT                      all  --  docker0 !docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT                      all  --  docker0 docker0  0.0.0.0/0            0.0.0.0/0           

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain DOCKER (1 references)
 pkts bytes target     prot opt in     out     source               destination         

Chain DOCKER-ISOLATION-STAGE-1 (1 references)
 pkts bytes target                      prot opt in         out         source               destination         
    0     0 DOCKER-ISOLATION-STAGE-2    all  --  docker0    !docker0    0.0.0.0/0            0.0.0.0/0           
    0     0 RETURN                      all  --  *          *           0.0.0.0/0            0.0.0.0/0           

Chain DOCKER-ISOLATION-STAGE-2 (1 references)
 pkts bytes target     prot opt in     out      source               destination         
    0     0 DROP       all  --  *      docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 RETURN     all  --  *      *        0.0.0.0/0            0.0.0.0/0           

Chain DOCKER-USER (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0 
```

```bash
iptables -L -v -n -t nat
```

```bash
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   49  7688 DOCKER     all  --  *      *       0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    1    60 MASQUERADE  all  --  *      !docker0  172.17.0.0/16        0.0.0.0/0           

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    1    60 DOCKER     all  --  *      *       0.0.0.0/0           !127.0.0.0/8          ADDRTYPE match dst-type LOCAL

Chain DOCKER (2 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 RETURN     all  --  docker0 *       0.0.0.0/0            0.0.0.0/0
```


```bash
docker run -d -p 8080:80 --name=lol nginx
```

```bash
Chain DOCKER (1 references)
 pkts bytes target     prot opt in          out         source      destination         
    0     0 ACCEPT     tcp  --  !docker0    docker0     0.0.0.0/0   172.17.0.2     tcp dpt:80
```

```
Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    1    60 MASQUERADE  all  --  *      !docker0  172.17.0.0/16        0.0.0.0/0           
    0     0 MASQUERADE  tcp  --  *      *       172.17.0.2           172.17.0.2           tcp dpt:80

...

Chain DOCKER (2 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 RETURN     all  --  docker0 *       0.0.0.0/0            0.0.0.0/0           
    0     0 DNAT       tcp  --  !docker0 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:172.17.0.2:80
```

```bash
docker run -d --name=lol nginx
```

```bash
iptables -A DOCKER ! -i docker0 -o docker0 -p tcp --dport 80 -s 0.0.0.0/0 -d 172.17.0.2
iptables -t nat -j DNAT -A DOCKER -p tcp ! -i docker0 --dport 8080 --to-destination 172.17.0.2:80
iptables -t nat -j MASQUERADE -A POSTROUTING -s 172.17.0.2 -d 172.17.0.2 -p tcp --dport 80
```

```bash
iptables -D DOCKER 1
iptables -t nat -D DOCKER 2
iptables -t nat -D POSTROUTING 2
```

```bash
iptables -t nat -I PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 172.17.0.2:80
iptables -t nat -I POSTROUTING -p tcp -s 172.17.0.2 -j SNAT --to 10.128.0.56


iptables -I DOCKER ! -o docker0 -p tcp --dport 80 -s 0.0.0.0/0 -d 172.17.0.2
iptables -t nat -A OUTPUT -o lo -p tcp --dport 30000 -j DNAT --to-destination 172.17.0.2:80
```