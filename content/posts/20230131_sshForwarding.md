+++
title = "Creating a SSH Tunnel to expose a web application from a workstation"
description = "Creating a SSH Tunnel to expose a web application from a workstation via a Google Cloud Virtual Machine"
tags = [
    "google-cloud",
]
date = "2023-01-31"
categories = [
    "google-cloud",
]
+++

There are some cases where we would need to host an application on our workstation but need it to be exposed publicly so that people would be able to access the application over the internet. There could be a variety of reasons for this to happen; e.g. data locality (too much data to transfer to the cloud - it might cost too much to store it in public cloud), application sensitivity (there are certain aspects that might make it bad to have it only run from public cloud - there is a need for applicaiton to be available on local network if there is no internet available), or maybe application can only be run on certain types of environment (e.g. mac). Most cloud vendors usually only provide windows and linux - mac environments are a bit on the rare side.

We would have to do a bunch of things to make this work - we'll cover the steps in this blog post.

## Getting a virtual machine from a public cloud

One of the steps involved would be getting a virtual machine from a public cloud. We can probably do it manually by going through a usual UI and simply request for a virtual machine for our use.

We would want to make sure that we would be able ssh into the machine from our local workstation to said virtual machine. We can test it via the following command:

```bash
ssh -i ~/.ssh/virtual_machine_user virtual_machine_user@34.100.100.100
```

In the above example, we have a virtual machine that is available on IP address 34.100.100.100. Let's say we created a new ssh key just for this scenario, we can put said private ssh key into the usual `~/.ssh` folder and reference the file while using the ssh command. Natually, you would want to make sure that the public version of the new ssh key is replicated into our virtual machine.

## Setting up application and the tunnel

On our local workstation, we would probably just setup the application accordingly. Important portion is to ensure that application is accesible from local workstation itself.

To setup ssh tunnel, we would run the following. The important parts would be -R flag - it would specify which port that we're trying to bind to on our remote machine to our application which would be hosted the local workstation on port 8080. 

The -N flag is used to indicate to the ssh command that there will be no remote command to be run. Usually, the shell or bash commands would invoked if no command is provided to the ssh command but we don't even want that to run - all we want is just a plain ssh tunnel that would ship data from our virtual machine to our application on the local workstation.

```bash
ssh -i ~/.ssh/virtual_machine_user -R 8080:127.0.0.1:8080 -N virtual_machine_user@34.100.100.100
```

## Setting up nginx on virtual machine

We would be exposing the application via a virtual machine on a public cloud. This blog post won't be covering on steps of how to create a virtual machine on a public cloud. However, we would be going some of the steps to setup nginx on the machine. To install nginx, we can run the following commands.

```bash
sudo apt update
sudo apt install -y nginx
```

With this, a nginx is available to use on the virtual machine. At this point, we can do a quick test to make sure that nginx is accessible from the internet. If there are issues with accessing the nginx server, there is probably firewall rules that need to be configured accordingly.

The next step would be configure the nginx so that when a user access the nginx server, it would immediately be forwarded to the local workstation's application. We can do this by altering the nginx configuration like so:

Edit the `/etc/nginx/sites-available/default`

```
        location /hehe {
                rewrite ^/hehe/?(.*)$ /$1 break;    
                proxy_pass  http://127.0.0.1:8080;
        }
```

This would mean that if our user tries to access any `/hehe` path on our server, we would be automatically redirected accordingly. 

Naturally, changes to the nginx configuration file would only be taken into account by reloading it

```bash
sudo nginx -t
sudo nginx -s reload
```

## Conclusion

The above is a basic setup of a ssh tunnel to access an application on our local workstation. However, there are definitely things that we would need to take note while doing this setup. It is pretty hard to recommend this approach unless you have a particularly good reason to not your application to the cloud. It almost feels like as though the setup is only for "testing" applications.

Doing this as follows would mean we are probably going into a situation where we would be deploying the application in a non-scalable way. It doesn't make sense for the application to create a bunch of ssh tunnels to the same virtual machine to have the application exposed publicly. For the services being setup in the following way, we should expect very little incoming traffic.

Another point of concern is that it is hard to guarantee the available of the application. There are many possible points of failure - application can fail, the ssh tunnel itself could hang/terminate prematurely.