+++
title = "Devops Interview Questions"
description = "Devops Interview Questions"
tags = [
    "devops",
    "kubernetes",
    "docker",
]
date = "2022-02-27"
categories = [
    "devops",
    "kubernetes",
    "docker",
]
+++

This is a list of notes for possible interview questions with regards to devops roles. Interview questions for devops are particularly hard to cover since devops roles generally cover a broad range of topics and technologies. I will update this page as I see any interesting or "hard" questions to cover.

Weirdly enough, a lot of the questions gather are usually "fringe" edge cases that one may accidentally come across due to unique use cases. 

I will update this post as time goes by - if there is more information on this

- [Generic](#generic)
  - [How is a computer assigned an IP Address in a LAN?](#how-is-a-computer-assigned-an-ip-address-in-a-lan)
  - [What happens when a user accesses a website from a website browser?](#what-happens-when-a-user-accesses-a-website-from-a-website-browser)
  - [What are the different kind of DNS Records?](#what-are-the-different-kind-of-dns-records)
  - [What are some differences between Redis and Memcached?](#what-are-some-differences-between-redis-and-memcached)
  - [What is the purpose of a Certificate Authority?](#what-is-the-purpose-of-a-certificate-authority)
  - [What's the difference between threads and processes?](#whats-the-difference-between-threads-and-processes)
  - [How do we monitor Java applications?](#how-do-we-monitor-java-applications)
  - [What is Swap space used for?](#what-is-swap-space-used-for)
  - [What are Huge pages in linux used for?](#what-are-huge-pages-in-linux-used-for)
  - [What is the difference between TCP/UDP?](#what-is-the-difference-between-tcpudp)
  - [What is ICMP?](#what-is-icmp)
  - [What are the fallacies of distributed computing?](#what-are-the-fallacies-of-distributed-computing)
  - [Any useful guidelines when deciding on what metrics that application should have?](#any-useful-guidelines-when-deciding-on-what-metrics-that-application-should-have)
  - [What are some useful linux commands?](#what-are-some-useful-linux-commands)
  - [What's the meaning of some of the following terms when handling systems:](#whats-the-meaning-of-some-of-the-following-terms-when-handling-systems)
  - [What are inodes, hard links and symlinks, file descriptors (FD) in linux filesystem?](#what-are-inodes-hard-links-and-symlinks-file-descriptors-fd-in-linux-filesystem)
  - [How does one improve security posture of deployments?](#how-does-one-improve-security-posture-of-deployments)
  - [IPTables Commands](#iptables-commands)
  - [How does MITM (Man in the Middle) attack work?](#how-does-mitm-man-in-the-middle-attack-work)
  - [How does TLS prevent MITM attack?](#how-does-tls-prevent-mitm-attack)
  - [What are Anycast IPs?](#what-are-anycast-ips)
  - [How does Anycast IPs work?](#how-does-anycast-ips-work)
  - [What is Apparmour and what does it do?](#what-is-apparmour-and-what-does-it-do)
  - [What is Seccomp and what does it do?](#what-is-seccomp-and-what-does-it-do)
  - [What are some of the steps one could take to harden a linux instance?](#what-are-some-of-the-steps-one-could-take-to-harden-a-linux-instance)
- [System Design](#system-design)
  - [References](#references)
  - [Design a commenting system](#design-a-commenting-system)
  - [Design a CDN](#design-a-cdn)
  - [Design a code-deployment system](#design-a-code-deployment-system)
  - [Design a API rate limiter system](#design-a-api-rate-limiter-system)
- [Docker](#docker)
  - [What's the difference between COPY and ADD?](#whats-the-difference-between-copy-and-add)
  - [What's the difference between CMD and ENTRYPOINT](#whats-the-difference-between-cmd-and-entrypoint)
  - [Why use Execution form over Shell form in Dockerfile](#why-use-execution-form-over-shell-form-in-dockerfile)
  - [How is isolation achieved in Docker?](#how-is-isolation-achieved-in-docker)
  - [How does volume mounting work in Docker?](#how-does-volume-mounting-work-in-docker)
  - [Assume you have an application that requires MySQL database. Assume that the app and database is deployed in 2 separated containers. Why can't the application use "localhost:3306" to connect to the database?](#assume-you-have-an-application-that-requires-mysql-database-assume-that-the-app-and-database-is-deployed-in-2-separated-containers-why-cant-the-application-use-localhost3306-to-connect-to-the-database)
- [Kubernetes](#kubernetes)
  - [What is the architecture of Kubernetes?](#what-is-the-architecture-of-kubernetes)
  - [We usually disable swap space when running Kubernetes 1.21 and earlier. Why?](#we-usually-disable-swap-space-when-running-kubernetes-121-and-earlier-why)
  - [What are some of the ways to expose application endpoints within k8s externally?](#what-are-some-of-the-ways-to-expose-application-endpoints-within-k8s-externally)
  - [What's the difference between statefulsets and deployments? And how does statefulsets allow databases to be deployed safely into Kubernetes?](#whats-the-difference-between-statefulsets-and-deployments-and-how-does-statefulsets-allow-databases-to-be-deployed-safely-into-kubernetes)
  - [How does a external network request reach into a pod via Ingress?](#how-does-a-external-network-request-reach-into-a-pod-via-ingress)
  - [How is volume mounting handled in Kubernetes?](#how-is-volume-mounting-handled-in-kubernetes)
  - [What is a headless service?](#what-is-a-headless-service)
  - [When creating operator - how are reconcilition loops started?](#when-creating-operator---how-are-reconcilition-loops-started)
  - [How does one achieve multi-tenancy in Kubernetes environment?](#how-does-one-achieve-multi-tenancy-in-kubernetes-environment)
  - [Why you can't ping a service?](#why-you-cant-ping-a-service)
  - [Debugging steps for Kubernetes Applications](#debugging-steps-for-kubernetes-applications)
  - [What are some of the security steps to harden Kubernetes deployments?](#what-are-some-of-the-security-steps-to-harden-kubernetes-deployments)
- [Databases](#databases)
  - [How does one go about to "reshard" a database](#how-does-one-go-about-to-reshard-a-database)
- [Useful links](#useful-links)


{{< ads_header >}}

## Generic

### How is a computer assigned an IP Address in a LAN?

- Either statically assigned an IP Address
- Generally, most computers on home networks/office network work with DHCP
  - Client computer broadcast a DHCP Broadcast Message (since no IP Address)
  - DHCP Server (Usually router) - responds with an IP Address to offer + Default gateway + Subnet Masks etc
  - Client computer responds with a request to "claim" the IP Address
  - DHCP responds with acknowledge that IP Address has been claimed, leases for a few hours (based on configuration of router). Acknowledge message may contain some additional "options" information such as DNS server etc. Technically, DHCP servers can be configured to issue such information accordingly. 

References: https://support.huawei.com/enterprise/en/doc/EDOC1000178170/225eec10/dhcp-messages

### What happens when a user accesses a website from a website browser?

- DNS Resolving
  - Check again local's `/etc/hosts` file to determine first level of dns resolve
  - Reach out the dns server on current local network if setup (e.g. running your own DNS server etc or usually hit the router) - all this information set during DHCP
  - If local network's DNS not available, the router hop would reach out to further out to provider/etc or other root authorative name servers. Possibly the network provider (e.g. In singapore, could be Starhub/Singtel's DNS servers)
  - All above would be skip if dns server to be lookup-ed on workstation is set in network configurations (e.g. 8.8.8.8, 8.8.4.4, 1.1.1.1)
- Connect to remote IP Address
  - Process start to connect to remote IP Address
  - Utilize some of the information to decide how to do the first hop
  - Utilize the subnetwork mask and check with IP Address - If "network" part is different for remote server - that would mean that request has to be sent to the Default Gateway (for local workstations - that would be the wifi router)
- TCP Handshake
  - It comes before TLS/SSL step
  - Client sends SYN (Synchronize Sequence Number)
  - Server sends SYN/ACK (Synchronize + Acknowledged)
  - Client sends ACK (To say that it has received the message)
- SSL Handshake or TLS Handshake
  - If website to be accessed is accessed via https
  - Refer to the following website for more details
    - Client Hello (Includes TLS version that client browser support + random string client)
    - Server Hello (Sends SSL cert with public key + cipher version chosen + random string from server)
    - Authentication (Client checks if SSL cert valid - e.g. not expired, valid chain of certs, trusted certs)
    - Premaster secret (Client generates a premaster secrets and encrypts with server public key and sends it over to server - can only be decrypted with server's private key)
    - Private key used (Server decrypts premaster secret)
    - Session key created (Both client and server generate session key using random client string, random server string and premaster key)
    - Client ready
    - Server ready
    - Handshake complete
- Fetch HTML from website (could come from server/CDN/Cached Responses in Load Balancer)
- While rendering HTML, fetch javascripts, images etc
  - Javascript could be used to fetch results from APIs etc.
  - To prevent security issues, CORS rules are set in place in browser, difficult to call APIs across domains

References:  
- https://www.youtube.com/watch?v=VONSx_ftkz8  

### What are the different kind of DNS Records?

- A Record - Mapping domain to IPv4 addresses
- AAAA Record - Mapping domain to IPv6 addresses
- CNAME Record - Mapping domain to another domain as an alias
- NS Record - Provide information on the authorivative DNS server for that domain
- MX Record - Provide information for where the emails meant for that domain is supposed to go
- TXT Record - Adding text information to the domain records (e.g. adding text to prove that you own the domain etc)

### What are some differences between Redis and Memcached?

Both are caching tools that store items in memory; however, due to different implementations, they come with their own set of restrictions or drawbacks.

- Memcached is very simplistic; Redis is very feature reach, can store complex data models
- Memcached doesn't even have cluster mode; Redis allows cluster mode to handle higher throughput. (Means for memcached - "cluster" mode would need to rely on clients - clients would need to implement all that logic)
- Memcached is multi-threaded while redis is "single threaded". Means, if any operation is blocking, no requests can be served till it's done.

References:
- https://medium.com/@jychen7/sharing-redis-single-thread-vs-multi-threads-5870bd44d153
- https://medium.com/@SkyscannerEng/scaling-memcached-cdef01e150a1
- https://github.com/memcached/memcached/wiki/Commands
- https://redis.io/commands

### What is the purpose of a Certificate Authority?

A certificate authority is usually an organization/private entity that would usually do validation of other websites by issuing digital certificates. A user who utilizes such third party certificate issuers would first need to create a private key and then a certificate signing request. The certificate signing request would be passed to the CA which would then be used to create the cert that the user can then use.

### What's the difference between threads and processes?

- Process is any program in execution vs threads being a segment of process
- Process are "heavy" and takes a while to start while threads are setup way faster
- Process have memory mapped different between processes but threads in a process share the same memory space
- (E.g. A golang application will run in a process which would setup 1 or more threads which would run goroutines that would manage threads by the Golang runtime)

### How do we monitor Java applications?

- Java applications are generally wrapped in its own runtime; in a Java Virtual Machine. A normal monitoring solution that attempts to monitor the server/container that runs the Java application will not reflect the true reality of how much memory that the Java application is actually using.
- Java application (at least JDK 8) - usually reserves a block on memory on startup
- Certain monitoring solutions such as prometheus would require such sort of exporter to export JVM metrics to show the true state of Java application

### What is Swap space used for?

In servers, there is a limit to how much memory that is available for the server to use (which includes running of important kernel level functionality). However, there are cases where the amount of memory on the memory is not sufficient. Swap space is essentially "disk space" where memory chunks are stored temporarily. Access to it is was slower (Memory access speeds >>> physical storage) - these might induce latency hits on application etc

Swap starts to get used more and more as space get used more and more, making the system more and more slower. You can see the impact of this on CPU - kernal need to spend a few cycles to move data around from storage back to memory to compute before dumping the results back into disk.

### What are Huge pages in linux used for?

Data is moved from slower storage to memory - this whole operation is all managed in blocks call pages. A typically page is 4Ki - essentially, memory is moved around and loaded up in 4Ki blocks at one time. I'd imagine that more data intensive applications would need to rely on this mechanism; sometimes, if the loading of data from storage is too slow, might be better to switch to using faster storages or loading larger chunks of data (at the cost of moving more data into memory)

One cost to take note of when handling is that memory chunk that is loaded in is quite big - kernel need to make space for it. As large chunks get allocated/deallocated, the memory will get more and more fragmented - kernel need to compact it to give it more space. (Expect CPU to go up)

E.g. Hadoop performance degradation with THP (but partly from bug) - https://www.ghostar.org/2015/02/transparent-huge-pages-on-hadoop-makes-me-sad/

I'd assume huge pages are less useful nowadays with SSD (this would be useful in the past). SSD is way faster than HDD so that should be the first optimization rather than looking at huge pages as the first optimization

### What is the difference between TCP/UDP?

TCP = Transmission Control Protocol  
UDP = User Datagram Protocol  

- TCP is connection based while UDP isn't. No need for UDP to initiate connection etc, can immediately send data over the wire
- TCP is able to sequence while UDP is not
- TCP is able to guarantee that transmission of data is done successfully but UDP is unable to
- TCP is able to check for correctness that data is sent successfully, UDP doesn't need to
- UDP faster than TCP (from lack of overhead)
- Usage:
  - TCP is used for HTTP/HTTPS, SMTP, FTP etc
  - UDP is used for video streaming, VoIP, DNS?

### What is ICMP?

ICMP - Internet Control Message Protocol. Generally used for diagonostic purposes during IP operations.  
Used via Ping commands or traceroute commands. From this, it would probably contain diagnostic information on what happen between source client and server - maybe one of the routing servers drop? Or packet got blcoked? Or port got blocked?  

### What are the fallacies of distributed computing?

- The network is reliable
- Latency is zero
- Bandwidth is infinite
- The network is secure
- Topology doesn't change
- There is one administrator
- Transport cost is zero
- The network is homogeneous

### Any useful guidelines when deciding on what metrics that application should have?

https://medium.com/thron-tech/how-we-implemented-red-and-use-metrics-for-monitoring-9a7db29382af

RED - Rate, Error %, Duration of request
USE - Usage, Saturation %, Error %

USE might be used for systems/metrics that have a "maximum" - e.g. storage etc
RED might be used for something that comes at a rate and theoretically have "no limits" - e.g. requests made to an application

### What are some useful linux commands?

Not in terms of importance:

```bash
# Important tooling to install (if missing)
sudo apt update
sudo apt install -y iputils-ping vim sysstat net-tools

# Management of components
sudo systemctl status <component>
sudo systemctl list-unit-files | grep enabled

# Viewing logs etc of components
sudo journalctl -u <component> -f --since "10 minutes ago" --no-pager

# Viewing which folder is taking the most logs
sudo du -sh $(ls)
df -h

# Finding a file
# https://www.tecmint.com/35-practical-examples-of-linux-find-command/
find / -name hosts

# Viewing performance at the moment (For quick debugging)
# apt install -y procps
top
# M (by Memory), N (by PID), P (by CPU - proceessor), T (by time)
# E (change units)
# t (cpu graph), m (memory graph), k (kill signal), c (show full command line), r (renice)
#
# First line in top: e.g. 
# 13:27:26 up 2 days, 18 min,  1 user,  load average: 0.00, 0.07, 0.09
# <uptime info> <load average by 1min, 5min, 15min - more than 1 is overworked>
#
# Third line in top: e.g.
# %Cpu(s):  0.3 us,  0.3 sy,  0.0 ni, 99.3 id,  0.0 wa,  0.0 hi,  0.1 si,  0.0 st
# us - % user processes
# sy - % system processes
# id - % idle time
# wa - % wait time for IO
# st - % wait for virtual CPU to access physical cpu

# Cleaning up logs
journalctl --vacuum-time=10d
journalctl --vacuum-size=500m

# Handling permission issues
sudo chmod +x <binary file>
sudo chown <user>:<group> <binary file>

# Viewing file
vim # Use j, k commands to jump up and down
head
tail
less
grep -c "INFO" logname.log
grep -ic "INFO" logname.log # inverse of above

# Disk related commands
sudo fdisk /dev/sdb -> Create a new partition
sudo fdisk -l
sudo mkfs -t ext4 /dev/sdb1
lsblk -f
sudo mount /dev/sdb1 /var/lib/mysql
# Make sure to edit /etc/fstab

# Network commands?
ifconfig
ip a # View logs
ping
nslookup <hostname>
dig <hostname> # apt install -y dnsutils
tcpdump #only if traffic is http or non-encrypted
nmap -O localhost # Find out which port is open
nmap -sU -O localhost # UDP Traffic port
nmap -sT -O localhost # TCP Traffic port
nmap -A <remote ip address> # Get details of remote server
netstat -tunlp # Check which ports are open
traceroute # There was a time where traffic for laptops for Starhub (while working) was dropping traffic?
arp # Get network equipment details
hostname # Get info of how the machine is presented to network

# Linux firewalls
iptables -L

# Open files
lsof -i -P -n # Find which process connected to which port

# Compare files
diff <filename1> <filename2>

# Check cpuinformation
cat /proc/cpuinfo

# Performance Troubleshooting Demos
# https://www.youtube.com/watch?v=rwVLa9me7e4&ab_channel=grobelDev
# https://netflixtechblog.com/linux-performance-analysis-in-60-000-milliseconds-accc10403c55?gi=3d8d7960fce4
uptime
dmesg -T | tail
vmstat 1            # Virtual Memory stats - if r > no of processes. bad
mpstat -P ALL 1     # Report processor stats - if one is busy but the rest is not - could be single threaded app
pidstat 1           # PID stats - check on pid level - which processes taking resources?
iostat -xz 1        # IO stats - check if io devices are the bottleneck?
free -m
sar -n DEV 1        # (System Activity Report) Networking check
sar -n TCP,ETCP 1   # Networking check
top                 # General overview of system - hard to capture short-lived processes
atop                # Top but with historical info
strace -tp `pgrep lab003` 2>&1 | head -100 # Check system calls (for detailed reasons for why app is so busy on system)
perf record -F 99 -a -g -- sleep 10 # Capture perf info
perf report -n --stdio
```

### What's the meaning of some of the following terms when handling systems:

- SLI - service level indicator
- SLO - service level objective
- SLA - service level agreement
- MTBF - Mean time between failures
- MTTR - Mean time to recovery or repair or respond (they all mean different things)
- RTO - Recovery Time Objective. Max amount of time since downtime allowed for services to recover to working order
- RPO - Recovery Point Objective. Max amount of time for which data is lost that the organization is willing or ok to lose 
- Incident Handling
- Post Mortem
- Root Cause Analysis

### What are inodes, hard links and symlinks, file descriptors (FD) in linux filesystem?

- Inodes are metadata for a file
- Hard links are the physical reference to a file - limited to one per file
- Symlinks - symbolic links are soft links to a file (essentially, its like a reference to a actual hard link)
- File Descriptions - are files that represent "open" files or "open" sockets (relates back to how linux was designed where everything would be ideally represented as a file)


### How does one improve security posture of deployments?

Note: Attestation means evidence or proof of something

- Ensure that dependencies that applications rely on is scanned to ensure that it doesn't contain malware
- Ensure that no secrets are in Git
- Utilizes services that allow secret rotation more easily (e.g Secrets Manager, vault etc)
- If applications are in containers
  - Ensure no secrets within it
  - Reduce attack surface by reducing amount of dependencies (use smaller images - e.g. slim or alpine or distroless images)
  - Scan container images to check for vulnerabilities
  - Maybe consider micro-vms (since if containers are broken out, can affect host's kernel)
  - Ensure container is non-root
- If applications are in Virtual Machines
  - Try to ensure that VMs are not exposed to internet unnecessarily. E.g. Google Compute Engine by default has public interface; if it doesn't need it, it shouldn't have it
  - Maybe consider the SPIFFE project - ensure that nodes can only talk to nodes that are within the "trusted" circle and have gone through the appropiate "attestation" to ensure that people know who the node is etc
- If applications are in Kubernetes
  - Use network policies to restrict applications that can communicate with each other
  - Possibility to utilize service mesh to somehow get users to communicate with each other using mTLS
  - Possibility to utilize Binary authorization with attested images (maybe to prove security scan is done etc)
  - Use separate service account and RBAC for applications (more granular permission control)
  - Set container such that it needs to be non-root to run it
  - Set container such that it doesn't need linux permsisions (unless required)
- For all deployments
  - Ensure that logs emitted from all applications do not print out security tokens/credentials or user information - need to have constant scanning of information
  - Ensure resource policies are set (to ensure no runaway application)
- Utilize linux tooling
  - Apparmor: Mandatory Access Control framework that functions as an LSM (Linux Security Module). It is used to whitelist or blacklist a subject's (program's) access to an object (file, path, etc.).
  - Seccomp: a Linux feature that allows a userspace program to set up syscall filters.
  - Dropping capabilities

### IPTables Commands

Here is a list of iptables commands (with explanations of what it's doing)

View the following youtube series: https://www.youtube.com/watch?v=xHwtG9S8Fwo&list=PLvadQtO-ihXt5k8XME2iv0cKpKhcYqe7i&index=2&ab_channel=SysEngQuick

```bash
apt install iptables-persistent
iptables-save > /etc/iptables/rules.v4

# Accept all input and output to be accepted
iptables -A INPUT -j ACCEPT
iptables -A OUTPUT -j ACCEPT

# Set default policies for input, forward and output chains
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Accept localhost interface (from ifconfig - view network interface)
iptables -A INPUT -j ACCEPT -i lo
iptables -A OUTPUT -j ACCEPT -o lo

# Easier to view and debug iptables rules - default is filter table
iptables -L -n -v --line-numbers

# View the NAT tables
iptables -L -n -v --line-numbers -t nat

# Allow currently established connections to continue
iptables -A INPUT -j ACCEPT -m conntrack --ctstate ESTABLISHED,RELATED
iptables -A INPUT -j OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED

# Adding comments
iptables -A INPUT -j ACCEPT -p tcp --dport -m comment --comment "Test comment"

# Deleting rules
iptables -D INPUT 1
iptables -D OUTPUT 1

# Adding specific examples for adding specific protocoles
iptables -A INPUT -j ACCEPT -p icmp --icmp-type=8
iptables -A INPUT -j ACCEPT -p tcp --dport 22
iptables -A OUTPUT -j ACCEPT -p icmp --icmp-type=8
iptables -A OUTPUT -j ACCEPT -p tcp --dport 22
iptables -A OUTPUT -j ACCEPT -p tcp --dport 80
iptables -A OUTPUT -j ACCEPT -p tcp --dport 443
iptables -A OUTPUT -j ACCEPT -p tcp --dport 53
iptables -A OUTPUT -j ACCEPT -p udp --dport 53
iptables -A OUTPUT -j ACCEPT -p udp --dport 123 # NTP traffic

iptables -A FORWARD -m comment --comment "established traffic" -j ACCEPT -m conntrack --ctstate ESTABLISHED,RELATED
iptables -A FORWARD -j ACCEPT -i lan -o wan

# To allow forward
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o wan -j MASQUERADE

iptables -t nat -A PREROUTING -p tcp --dport 22 -d 192.168.5.201 -j DNAT --to-destination 172.16.1.102
iptables -A FORWARD -p tcp --dport 22 -d 172.16.1.102 -j ACCEPT
```

### How does MITM (Man in the Middle) attack work?

TODO: Add content

### How does TLS prevent MITM attack?

TODO: Add content

### What are Anycast IPs?

TODO: Add content

### How does Anycast IPs work?

TODO: Add content

### What is Apparmour and what does it do?

TODO: Add content

### What is Seccomp and what does it do?

TODO: Add content

### What are some of the steps one could take to harden a linux instance?

TODO: Add content

{{< ads_header >}}

## System Design

### References

https://mecha-mind.medium.com/

### Design a commenting system

TODO: Add content

### Design a CDN

TODO: Add content

### Design a code-deployment system

- Which aspect of the code deployment pipeline?
  - Need to involve CI portion? E.g. testing to ensure that application is fine before deployment? testing to ensure that application is fine after deployment
- What kind of code are we shipping?
  - Packaged into binary packages etc?
  - Packaged into VMs (e.g. Using packer)
  - Packaged into Container images?
- What sort of environment will the code be deployed into?
  - Public Cloud?
  - Privately owned datacentres?
- How to get artifacts into target environments?
  - Allowed to rely on public cloud?
  - Need to be able to sync large objects across datacentres
- How to ensure releases a synced across datacentres?
  - Config file that are synced to ensure that all are of the same version
  - Not all datacentres are of same size (Different DCs have different set of performance) - need to adjust datacentre configuration accordingly
- Monitoring of all process/pipelines
  - Syncing of artifacts between the various datacentres?
  - Syncing of data centre configurations (Either manually start the process to sync up? Or automatically have the dc have some sort of binary/controller to update the process accordingly)

### Design a API rate limiter system

https://medium.com/geekculture/system-design-basics-rate-limiter-351c09a57d14

- Algorithms
  - Leaky bucket (Need a big cache to store items to be outflowed?)
  - Token bucket (Have a token generator -> service to serve traffic will fetch token before serving it into system)
  - Fixed Window Counter (Have a counter for each duration of time, reset once next counter begins)
  - Sliding Log (Cache all requests with timestamp, and serve sufficient traffic to hit request rate)
  - Sliding Window (Combines concept of fixed window counter and sliding log)
- Handling API rate limiting in a large distributed system
  - Centralized datastore to store api request count? Introduces potential amount of latency?

## Docker

### What's the difference between COPY and ADD?

- ADD was probably introduced earlier - ADD can add files from local filesystem into container. It can also pull from remote sources into container. It can also auto extract files from tar files into docker image
- COPY can only do local filesystem into container
- COPY is the more "secure" solution here of sorts

### What's the difference between CMD and ENTRYPOINT

- CMD -> Set default parameters that can be over-rided from CLI
- ENTRYPOINT -> Set default parameters that cannot be over-rided from CLI
- CMD used when building applications but ENTRYPOINT could be used for "utility" containers (e.g. yq container - only need to pass in flags)

Reference: https://www.bmc.com/blogs/docker-cmd-vs-entrypoint/

### Why use Execution form over Shell form in Dockerfile

- Shell form in dockerfile -> e.g. `CMD ./app`
- Executable form in dockerfile -> e.g. `CMD ["./app"]`
- Shell command form always passes within a shell and goes through various shell validation before returning results - its like a shell that warps the string provided to it
- Executable form skips shell validation and processing - immediately invokes commands
- Issues when running app with shell command form - the "sh" command is invoke, cancelling it doesn't exactly cancel the app, it kills the app but not the shell -> causing issues (hang on terminal)
### How is isolation achieved in Docker?

- Refer to the following video: https://www.youtube.com/watch?v=8fi7uSYlOdc
- Refer to the following code for the video here: https://github.com/lizrice/containers-from-scratch
- A container is essentially:
  - Linux namespaces
    - These act as a filter on what you can see from within the container
    - E.g. For `ps` command - you can only see pids within that container
    - E.g. For networks interfaces `ifconfig` command - you can only see network interfaces relevant to that container within it
  - Cgroups
    - Mechanism that allows one to limit resources to a process
    - E.g. cpu/memory etc
- Building that container runtime might involve:
  - Setting the hostname
  - Changing root fs to something to another folder (different from host)
  - Ensure that directory on top level is /
  - Mount "proc" into container so that ps works

### How does volume mounting work in Docker?

Docker CLI will communicate with Docker local "server" daemon, reference: https://github.com/docker/cli/blob/cf8c4bab6477ef62122bda875f80d8472005010d/vendor/github.com/docker/docker/client/container_create.go#L54

- From docker-cli repo (a "post" request call to create container) -> moby/moby repo
- daemon pkg -> createContainer call which then calls specific os specific settings.
- daemon pkg -> createContainerOSSpecificSettings
- volume/service pkg -> Ask volume service to create -> Ask volume store to create -> Ask volume driver to create -> (Default Mac docker volume plugin uses local -> Creates directory and sets permission)
- container pkg -> AddMountPointWithVolume (just object representation)
- daemon pkg -> populateVolumes
- Calls Volume mounts from moby/sys repo
- Final unix mount command: https://github.com/moby/sys/blob/main/mount/mounter_linux.go#L30

### Assume you have an application that requires MySQL database. Assume that the app and database is deployed in 2 separated containers. Why can't the application use "localhost:3306" to connect to the database?

- Firstly, need to understand the following aspects:
  - On mac/windows, all docker containers are run in a mini linux vms that is provided via docker desktop
  - When an app is exposed from docker container to host using `-p` flag; it is traversing from the app -> mini linux VM (Docker vm) -> exposed vm's port -> Host machine -> expose it on host machine
- Docker's network is designed that each container is referred to its own ip address
- Applications in a single container's localhost won't have MySQL installed in it
- The application in that container need to reach to the other container to access MySQL
- In default docker network bridge - need to use IP address (Apparently service discovery is not done properly in the past and is now probably kept for backward compatability)
  - https://docs.docker.com/network/network-tutorial-standalone/
  - https://stackoverflow.com/questions/41400603/dockers-embedded-dns-on-the-default-bridged-network
- Create a separate new bridge network and one can connect via names (don't forget to use `--name` flag when running docker container)
- Or alternatively, use docker-compose


{{< ads_header >}}

## Kubernetes

### What is the architecture of Kubernetes?

Consists of the following components:

Control plane components

- etcd (store state of k8s)
- api-server (expose k8s api)
- kube-controller-manager (has multiple controller for various k8s assets e.g. jobs, endpoints etc)
- kube-scheduler (handles scheduling of pods taking into account of taints, annotations, constraints, affinities)
- cloud-controller-manager (manager that would communicate with the hosting provider)
- cAdvisor (component that actual pull metrics about container cpu/metrics from cgroup linux fs) -> inbuilt into kubelet
- heapster/metrics server (to be used to serve metrics about k8s components, taken up by kube-apiserver etc - to handle horizontal pod autoscaling etc)
- kubeDNS/coreDNS - handles the DNS of the cluster. For CoreDNS, it startups by connecting to kubeapi and then watching endpoint objects and map it accordingly

Node components

- kubelet (agent that make sure pod is running on node)
- Kube-proxy
  - Refer to the video: https://www.youtube.com/watch?v=BxDnv7MpJ0I
  - (No longer valid - userspace mode) Intercepts connections to clusterIP of pods (Does not actually do proxying of rules)
  - (No longer valid - userspace mode) Does load balancing of traffic to k8s services
  - Kube-proxy maintains iptables rules (if iptables mode is used) -> relies on linux capabilities
  - Kube-proxy does this by watching endpoints -> once endpoint pops into existance, it adds it to be a place that can be proxied
  - For requests that come in with DNS -> resolved with coredns
- Container runtime (Default is now containerd) - doesn't matter as long as runtime supports OCI spec
- Container Networking Interface (CNI) - run daemon that sets up the overlay network for the cluster
  - Main responsibility of setting up overlay network
  - Manage IP address (IPAM) - IP Address Management plugin is included in it
- Container Storage Interface (Managing of storage mounts)
  - Watching of PV and PVC objects and the controller will report to the daemon to handle the mounting/unmounting as well as cleanup of it

Reference: https://kubernetes.io/docs/concepts/overview/components/



### We usually disable swap space when running Kubernetes 1.21 and earlier. Why?

Swap space is essentially disk space which is a temporary place that memory "overflows" into. Disk is way way slower as compared to memory - enabling this make the performance of application extremely variable and unstable; we'll not be super sure which container has its memory written onto disk etc.

As mentioned in a blog post on Kubernetes blogs, there is a check to ensure that swap space is disabled (kubelet will not start if this check fails - or if you just ignore the checks)

Reference:  
https://kubernetes.io/blog/2021/08/09/run-nodes-with-swap-alpha/

### What are some of the ways to expose application endpoints within k8s externally?

- Ingress
  - Depends on how the Kubernetes cluster is setup and its cloud environment
  - In Google Kubernetes Engine, a load balancer is actually created and routes are created onto it. The routes that reflect back into the cluster; providing a single external IP address that routes based on the ingresses defined.
- Nodeports
  - Specified within Kubernetes Service objects
  - Maps the ports exposed from the container to port on host machine on reserved ports of 30000-32768
- Load Balancer
  - Specified within Kubernetes Service objects
  - In a cloud based environment, there will be a controller monitoring the service objects being created that requests for load balancers. It will communicate with its own respective clouds to create a load balancer and attach the external load balancer to that service.


### What's the difference between statefulsets and deployments? And how does statefulsets allow databases to be deployed safely into Kubernetes?

- Statefulsets has ordinal number at the back of pod name
- Stable pod name/name reference (can call specific pod in the stateful set)
- Pods in statefulsets can be accessed via headless services (no IP address for that service, you can access a specific pod via that service)
- If there are volumes to be mounted to it (via Persistent Volumes + Persistent Volume Claim) - each pod will have its own volume (unlike deployment where the persistent volume/volume claim is shared across the pods in deployment). This is done via VolumeClaimTemplates instead of VOlumeClaim

### How does a external network request reach into a pod via Ingress?

Coming

### How is volume mounting handled in Kubernetes?

Depends but nowadays, Container Storage Interface (CSI) is one of the ways that seems to becoming mainstream was to get volume mounting into Kubernetes. Previously, for some of the code - this code is "in-tree" but its slowly being moved out.

In the Kubernetes cluster, you can define multiple "storage classes" - which you can then put into Kubernetes PV definition on which class of storage you want for the application. E.g. SSD (which is definitely more expensive) vs HDD storage class.

For some storage types (e.g. Local) - require manual creation of disks that needs to be managed by an administrator. A lot of effort and very hard to scale out

For other storage types (e.g. GCE-PD) - supports dynamic mode and a controller can be made available that would be able to create the disk and mount it to the node accordingly. This definition is based of PVC - no need to create PV for this (controller probably creates for the user of the PVC)

### What is a headless service?

- A kubernetes service that does not set a IP address for that Kubernetes service
- Done by setting clusterIP to None
- In `nslookup <service name>`, it will list all IP address behind that service name
- Example of how headless service is useful
  - GRPC application that would utilize that absorbs all IP address where GRPC would load balance the applications across the pods
  - Use also for Statefulful set applications. To hit one of the pod via headless service - `<pod name>.<full service name>`

### When creating operator - how are reconcilition loops started?

Within the `xxxxx_controller.go` file (based on kube-builder framework), it would usually contain some code to build up the controller manager object. The object build up with various properties (builder pattern) but the most important one would be `For(...)` - that would identify kind of object that controller is managed. The `Complete` method would invoke various controller functionality; the kubernetes "watch" functionality is invoked. 

Reference: https://github.com/kubernetes-sigs/controller-runtime/blob/master/pkg/builder/controller.go#L81 (May not be accurate)

Reference for watch documentation: https://kubernetes.io/docs/reference/using-api/api-concepts/#efficient-detection-of-changes

Possible youtube video on details of this: https://www.youtube.com/watch?v=PLSDvFjR9HY


### How does one achieve multi-tenancy in Kubernetes environment?

Aim of multi-tenancy is to try to ensure that multiple application teams can share a single cluster and their usage of resources of the cluster does not have a wide blast zone

- Utilizing rbac on developer accounts attempting to access Kubernetes cluster to ensure that they have restricted access to certain resources
- Namespaces between teams
- Introduce resource quota and restrict it on per team basis
- Utilizing pod affinity rules to ensure that pods from different teams are not deployed to same nodes
- Utilizing taints and tolerations to probably try to book certain nodes for certain teams

### Why you can't ping a service?

(NEED TO CONFIRM - BEHAVIOUR FOR THIS IS NOT CONSISTENT)
https://nigelpoulton.com/why-you-cant-ping-a-kubernetes-service/
### Debugging steps for Kubernetes Applications

How do we start debugging an application that is deployed on Kubernetes

- Ensure that application works fine locally (can compile and can run without issues)
- Ensure that application works fine after its packaged in docker image
- Check Kubernetes manifest files/Helm chart to make sure that it works fine (make sure right ports are set)
- Check describe of pods if pods fail to start
  - `kubectl describe <pod name>`
  - Check health and readiness checks
  - Describe of pods could say that secrets/configmaps missing
  - Could be lack of resources in cluster
  - Could be no nodes that allow pod to exist (tolerations)
- Check logs of the pods (could have multiple pods)
  - `kubectl logs -f <pod name> -c <container name>`
  - Could be database migration failure (Appication will fail to start?)
  - Could be configuration error
- Try a "restart" first
  - `kubectl delete pods <pod name>`
  - OR
  - `kubectl rollout restart deployment <deployment name>`
- If issue with other components connecting to it
  - Check if can enter shell of image
  - `kubectl exec -it <pod name> -- /bin/bash`
  - Can check if application works from within application
  - Run same check from other pods (Could be that app was compiled to listen only to "127.0.0.1")
  - If other component is using service, ensure that matchLabels is service match pod labels (NOT deployment labels)
- More elaborate debugging steps (In case shell not present)
  - Copy pod while adding new container: `kubectl debug <pod name> -it --image=ubuntu --share-processes --copy-to=debugging-pod`
  - Copy pod while changing its command: `kubectl debug <pod name> -it --copy-to=debugging-pod --container=<pod name> -- sh`
  - Debug with shell on node: `kubectl debug node/<node name> -it --image=ubuntu`
- Additional cheatsheet for reference: https://kubernetes.io/docs/reference/kubectl/cheatsheet/

### What are some of the security steps to harden Kubernetes deployments?

- NSA Hardening Guide: https://www.nsa.gov/Press-Room/News-Highlights/Article/Article/2716980/nsa-cisa-release-kubernetes-hardening-guidance/
  - Ensure each container has read only root filesystem
  - Prevent containers from accessing host files using high GIDs
  - Don't use k8s host path to mount volumes
  - Prevent containers from escalating privileges (`securityContext.allowPrivilegeEscalation: false`)
  - Prevent containers from running with root priviliges (`securityContext.runAsRoot: false` in k8s deployment)
  - Prevent service acccount token (k8s service account) to be auto-mounted on pods
  - Set requests and limits to prevent runaway containers
- Do not run build process (e.g. Docker build) in production Kubernetes clusters (they have arbitrary commands to run commands)
- Scan built docker images to ensure no security issues
- Ensure you do not use the `--privileged` docker flags in docker and kubernetes
- Ensure that secrets are encrypted at rest and transit (either encrypt etcd or use KMS or Hashicorp vault)
- Prevent container drift (someone went into the container to modify the running image)
- Implement network policies (set policy for which pod can talk to which pod)

## Databases

### How does one go about to "reshard" a database

TODO: Add content

## Useful links

- https://www.hairizuan.com/experimenting-with-ip-tables/
- https://www.hairizuan.com/application-performance-isnt-the-most-important-factor-in-application-development/
- https://www.hairizuan.com/basic-ssl-setup-server-and-client-ssl-certificate-setup/