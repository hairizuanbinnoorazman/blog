+++
title = "Building Nginx RPM from source"
description = "Building Nginx RPM from source. Done on Google Cloud Platform - Centos 7"
tags = [
    "google cloud",
]
date = "2021-05-01"
categories = [
    "google cloud",
]
+++

NOTE: As software advances, some of the commands shown below may become depreciated/irrelevant. If one encounters errors - check the output logs to see what the issue is (e.g. missing library? missing dependency? wrong folder structure due to being unable to find a file)

These are some notes when it comes to building Nginx RPM for centos use. This can be used to further customize Nginx RPM

Create a Google Compute Engine with Centos 7 OS

Install required yum dependencies - some are needed to run commands (e.g. make, wget, git etc)

```bash
sudo yum install -y git wget make \
  gcc rpm-build GeoIP-devel zlib-devel \
  pcre-devel gd-devel libedit-devel which \
  perl-devel perl-ExtUtils-Embed libxslt-devel \
  openssl-devel
```

Import the nginx source code. Apparently, google mirrored the mercurial nginx source code to the following repo. We can safely use git to clone the source code and then checkout out one of the latest version of nginx and try to build up the rpm.

```bash
# Clone source code
git clone https://nginx.googlesource.com/nginx-pkgoss

# Enter the folder which contains source code
cd nginx-pkgoss

# Go to specific version of nginx release
git checkout nginx-1.19.8

# Go into rpm folder to view the Makefiles
cd ./rpm/SPECS

# Run make command to build all modules - there are other options
# The main one to ensure that it is possible to build would be "base"
make all
```

View the built rpm and test it out to ensure that we can run it etc

```bash
# Find the built nginx rpms
cd $HOME/nginx-pkgoss/rpm/RPMS/x86_64

# Install the dependencies for nginx
sudo yum install -y openssl
# Check openssl version to ensure its installed
openssl version

# Install the built nginx rpm
sudo rpm -i nginx-1.19.8-1.el7.ngx.x86_64.rpm 
# Check nginx is installed and is available for use
nginx -V

# Start nginx
sudo systemctl start nginx

# Check to ensure that nginx is working and is in running state
sudo systemctl status nginx

# Run curl command to ensure that nginx is able to actually serve the traffic
curl localhost
```

This should be the output you should be receiving to show that nginx server is properly started and can receive traffic accordingly

```html
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