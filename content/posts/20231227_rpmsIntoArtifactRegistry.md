+++
title = "Building RPMs and storing it in Artifact Registry"
description = "Building RPMs and storing it in Artifact Registry"
tags = [
    "google-cloud",
    "cicd",
]
date = "2023-12-27"
categories = [
    "google-cloud",
    "cicd",
]
+++

## Introduction

When one mentions about application packaging - the usual first thought that can cross a person's mind is how the application would be packaged in docker containers. That is a somewhat fair thing to think about - containers have gotten pretty common in developer circles. Tools such as docker or podman make it especially simple to write a simple straight forward file that would include their application file into a nice package. With this nice package - the people that are involved with running it production environments would only deal with a single artifact.

There are many other possible ways to package application. Another alternative way to package applications would be toss it into a Virtual Machine image. In the case where you use Amazon Web Services, you would copy the application and whatever necessary configuration into it. After the service is observed to be in a pretty decent state (running in a stable manner), we can simply shut off the instance and then "export" it as a Amazon Machine Image. In the case where us as users would need to run a single instance, we can simply request for AWS to use our Amazon Machine Image as the template virtual machine image and immediately start our application servers. There wouldn't be any further need to install and copy our application binaries and configuration etc. One tool that can help with this is terraform - which is also another pretty popular tool when it comes creating virtual images. Sadly enough though, each cloud and each hypervisor has different formats for the image itself. In AWS - we would need AMI (Amazon Machine Images). In Google Cloud - we would have Compute Images -> they are all different from each other.

This time round, for this blog post, I will be focusing on one of the alternatives of packaging application which is via RPMs. RPMs is a common packaging format if we are to work with Centos OS or Red Hat Linux Distributions. These OS-es are often used in the enterprise world - so it's pretty likely that you would come across it.

## Building a RPM with Golang application

For this blog post, I will be covering on how to build a RPM that would contain a Golang application. Upon install of RPM to a linux machine, it should be able to start the Golang application server and it should be managed by Systemd - there is a bunch of files that we would need to create as well a bunch of commands that we would need to run in order to get it running.

In order to build our RPM, we would need to create some sort of RPM spec file.

```bash
Name:       basic
Version:    0
Release:    1
Summary:    RPM package to contain basic Golang app
License:    FIXME

%description
RPM package to encapsulate basic golang application

%prep
# we have no source, so nothing here

%build
# Built using Golang docker image

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}/etc/systemd/system/
install -m 755 app %{buildroot}%{_bindir}/app
install -m 755 app.service %{buildroot}/etc/systemd/system/basic.service

%files
%{_bindir}/app
/etc/systemd/system/basic.service

%pre
getent group app >/dev/null 2>&1 || groupadd app
getent passwd app >/dev/null 2>&1 || useradd -G app app

%post
chown app:app %{_bindir}/app
systemctl daemon-reload
systemctl enable basic.service
systemctl start basic.service

%preun
systemctl stop basic.service
systemctl disable basic.service
systemctl daemon-reload
# systemctl reset-failed - not sure if needed here

%postun
userdel app
groupdel app

%changelog
# let's skip this for now
```

In order to build our RPMs, we would need a Centos or Rocky or a somewhat similar OS. We need some of the tooling within it that would be used for packaging our RPM - however, by default, the default Centos or Rocky environments won't come with language runtimes that we might need in order to build out and compile our application. In our case, we would need the Golang language runtime - and there doesn't seem to be any convenient virtual machine or docker image that has Golang within a Centos environment.

Since things are these way - the sane approach here is to simply rely multistage docker builds.

```Dockerfile
FROM golang:1.18 as builder
WORKDIR /helloworld
ADD . .
RUN CGO_ENABLED=0 go build -o app .

FROM rockylinux:8 as rpm-builder
RUN dnf install -y gcc rpm-build rpm-devel rpmlint make python3.11 bash diffutils patch rpmdevtools
WORKDIR /helloworld
COPY basic.spec .
RUN rpmdev-setuptree
COPY --from=builder /helloworld/app /root/rpmbuild/BUILD/app
COPY ./deployment/bin/app.service /root/rpmbuild/BUILD/app.service
RUN rpmbuild -ba basic.spec

FROM scratch
COPY --from=rpm-builder /root/rpmbuild/RPMS /
```

The first part would simply rely on a Golang docker image that would simply focus on building out our Golang application into a static binary. The second part would build out our rpm. Our rpm would contain the compiled Golang application and the systemd configuration. Ideally, the built rpm should also have the capability to move the golang application to the right folder as well as to setup the systemd files to manage the golang application. In order to get the built RPM out would be to simply copy it to a scratch container and then to simply copy the RPMs to a folder within a scratch container to our host machine. We will run the above Dockerfile with the following command:

```bash
docker build -f <dockerfile location> -t rpmbuilder --output out .
```

The output which is a folder that contains our RPM would be in the `out` folder.

## Testing the built RPM

We can test our built RPM on a virtual machine by going to any cloud provider to provision one. We can't fully test it in a docker image since our RPM utilizes systemd. Systemd doesn't exactly exist in container land (something along the line where systemd should on PID 1 but containers usually need the command defined via Entrypoint/CMD/from docker CLI instead)

We can simply do a `scp` to copy the RPM over to our server.

Once the RPM is on the machine, we can simply install the RPMs but running the following command:

```bash
rpm -Uvh basic-0-1.x86_64.rpm
```

To uninstall the rpm, we would simply need to list out what is installed on our server

```bash
rpm -qa | grep basic
```

And then, to remove it ("erase")

```bash
rpm -e basic-0.1.x86_64
```

THe above commands are simply examples - modify it according to the version that was specified for your rpm spec.

## Conclusion

The above RPM being created from this post is pretty simple and doesn't cover many of the features that RPMs would generally cover. One can simply look at the below link from pld-linux github link which seems to provide many other rpm spec files for many of the rpms available in the yum repos.

Maybe in the future, I'll write another blog post if I come across an interesting feature while building RPMs.

References:
- Some of the macros available in rpm spec  
  https://docs.fedoraproject.org/en-US/packaging-guidelines/RPMMacros/
- Some examples of rpm spec files.  
  https://github.com/pld-linux
- Maximum RPM guide book
  http://rpm5.org/docs/max-rpm.html