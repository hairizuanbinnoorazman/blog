+++
title = "Private VPC Experimentation"
description = "Private VPC Experimentation with Private VPC, Cloud Router, Cloud NAT, Cloud DNS, VPC Peering products"
tags = [
    "devops",
    "google-cloud",
]
date = "2022-05-05"
categories = [
    "devops",
    "google-cloud",
]
+++

This blog post is kind of a blog post that provide some notes of some experimentation that I encountered while playing with Google Cloud Platform. The purpose of this experimentation was to do the following:

- Have 1 instance on VPC A
  - The following instance will be in a private VPC
  - Nginx will be installed on this instance - so it would require internet access
- Have 1 other instance on VPC B
  - Instance is able to hit the instance from VPC A on DNS address (or a friendly name and not via a IP Address)
- Both instances are able to talk to each other

## Creating another VPC for testing

In a normal Google Cloud Project, it would only contain only the "default" VPC. If we are to experiment the whole VPC Peering and testing connection between 2 VPCs, we would need 2 VPCs - thereby, it means that we would need to create another VPC.

An important thing to note here is that if we wish for VPC Peering to perform correctly in later stages, we would need to ensure that the IP Addresses are different for the VPCs we're trying to connect together.

E.g. Let's say we're trying to US-central1 from both VPCs, and if we had used "automatic" during subnet creation mode while trying create another VPC - it would use the same CIDR. That would result VPC Peering to fail. Best to set up a custom setup.

What I've tried here was to use the following parameters:  
- VPC Name: testing
- Custom Subnet 1 Name: us-central1
- Region: us-central1
- CIDR: 10.129.0.0/20

Ensure that firewall rules such as those that allow for SSH is created as well. The firewall should be similar to the one defined in "default" VPC which is to allow from all IPs (0.0.0.0/0) - to reduce the hassle during experimentation.

## Creating instances with no external IPs

I suppose one way to reduce attack surface is to ensure that only instances that need to be exposed to the internet will have external IPs. Otherwise, they should not be assigned an external IP - so they can't exactly be "accessed" from the internet.

This is done during instance creation page:  
- Scroll down to "additional options" of "NETWORKING, DISKS, SECURITY, MANAGEMENT and SOLE-TENANCY"
- Scroll downwards to network dropdown tab
- Edit Network interfaces
  - For 1 instance - Choose default VPC
  - For the other - Choose testing VPC
  - Both in US-central1
  - External IP - set to None for both cases
  - No network tag is needed here in a sense

After creating the instance, we can try to SSH from the Google Cloud Console UI page and try to run some simple command to reach out to the internet; we would realize that we can't connect to the internet (this is to be expected). We can do this by running the below command:

```bash
sudo apt update
```

The command will hang when it attempts to reach to an external address and realizes it can't resolve nor route to it.

## Giving instance in default VPC internet accesss

We would only want to experiment where instance in the "default" VPC would have nginx installed. To do this, we would need internet access in the following VPC for those instances with no external IP Address.

To do so, we would need to setup a Cloud NAT. The setup of Cloud NAT is simple via UI on Google Cloud Console. While creating the Cloud NAT, it would require us to provide some sort of Cloud Router; we can just create a new Cloud Router from the same page.

Most of the parameters during creation of Cloud NAT and Cloud Router is just the name of the Cloud NAT and Cloud Router. Names should be sensible so that it would make sense from reports.

We can only provide internet to one subnet group at one time. For each of the other subnet groups, we would need to create one NAT for each of them. (Might be troublesome operationally)

To test, we can go back and ssh the instance that is in "default" VPC and run the command:

```bash
sudo apt update && sudo apt install -y nginx
```

This time, it would work as expected (assuming NAT was setup successfully)

## VPC Peering

We would need to set up 2 VPC Peerings links between the 2 VPCs.

- Connection from default VPC to testing VPC
- Connection from testing VPC to default VPC

If one of those is missing, the VPC Peering will be set to inactive state

To test VPC Peering is working is successfully, we can just attempt VPCs from across another VPC. 

E.g. If default VPC has an instance with IP Address `10.128.0.35`, we can run the ping command from the instance in the testing VPC

```bash
ping 10.128.0.35
```

If the setup is successful, we would get the following result:

```bash
PING 10.128.0.35 (10.128.0.35) 56(84) bytes of data.
64 bytes from 10.128.0.35: icmp_seq=1 ttl=64 time=1.86 ms
64 bytes from 10.128.0.35: icmp_seq=2 ttl=64 time=0.299 ms
```

Note, that we cannot refer instances by name across VPCs.

E.g. If instance in "default" VPC is called "instance-1", it can generally be referred by name by pinging `instance-1`. However, DNS names apparently is not resolved across VPC Peering. There is a question on some forum about it here: https://serverfault.com/questions/1005112/gcp-how-to-do-dns-peering-between-2-vpcs-that-use-vpc-peering-in-the-same-proje

This would make things slightly brittle if we are required to refer to other instances over in the other VPC via IP Addresses.

## Providing DNS across VPCs

I'm not sure if this is the right way to things, but this is definitely one lazy way out for this issue. We can rely on Cloud DNS product where we can register private DNS entries and then have it exposed on both VPCs. We can do this whole registering of new instances and associate the address of the new instance and its DNS name by calling some gcloud command: https://cloud.google.com/sdk/gcloud/reference/dns/record-sets/create. This is done by creating a "A" record that would refer to the instance correspondingly, and then map it to a relevant domain name.

E.g. let's say our DNS Zone that we created in Cloud DNS uses the overall domain of "example.com". We can register a "A" record which maps "hoho.example.com" that maps an IP address of `10.128.0.35` to that domain. If we try to ping it from either VPC, it should work:

```bash
PING hoho.example.com (10.128.0.35) 56(84) bytes of data.
64 bytes from 10.128.0.35 (10.128.0.35): icmp_seq=1 ttl=64 time=1.36 ms
64 bytes from 10.128.0.35 (10.128.0.35): icmp_seq=2 ttl=64 time=0.395 ms
```

Seeing that we've already installed nginx in the instance in the "default" VPC, we can run a curl command from the instance in the "testing" VPC in it for the domain "hoho.example.com"

```bash
# From instance in "testing" VPC
curl hoho.example.com
```

It should return the following output - essentially the standard nginx output:

```bash
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```