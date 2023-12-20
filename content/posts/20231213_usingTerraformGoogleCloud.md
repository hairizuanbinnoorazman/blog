+++
title = "Using Terraform for deploying databases and applications in Google Cloud"
description = "Using Terraform for deploying databases and application in Google Cloud"
tags = [
    "google-cloud",
    "cicd",
]
date = "2023-12-13"
categories = [
    "google-cloud",
    "cicd",
]
+++

Over the past few months, I have been toying with the idea of going all in with Ansible or all in with Terraform. Both tools are pretty popular tools when it comes to application and tools deployment. After tinkering around, I eventually somewhat come to conclusion where Terraform would be the "better" tool here. The main reason for this all comes down to this: https://github.com/ansible-collections/google.cloud/issues/301 - it seems that Ansible is not as "supported" as Terraform - and the more it seems that there are certain features that I may want to use to be missing. Rather than continue tinkering and hoping that something would happen (sometimes, these kind of code would never be resolved/fixed - it's possible for me to dig into it to try to solve but I don't feel like investing into this particular tool in depth)

And here we are, me trying out Terraform in order to deploy some stuff in Google Cloud via Terraform.

## Initial setup

One of the first things to build out would be the following setup:

- Setup of instances within a private virtual network
  - Generally done for better security - one way to secure servers would simply to avoid outsidrs from unnecessarily accessing it
- Setup of bastion host
  - This should be publicly accessible via ssh.
  - This host would serve as a "jump" server that would allow an outside developer to access the various instances within the private network
- Ensure that instance within the private virtual network is able to access the internet
  - If one were to create a Google Compute Engine with no public interface, you would realize that the instance wouldn't be able to access the internet. In order for such instances to be able access the internet, we would need to setup a NAT connected to the VPN - from then on, it should be able to access the internet.

The first thing I would want to deploy in order to ensure that the internet works properly would be to install docker on the instance within the virtual private network. I generally use docker in various experiments so it would usually be the first things I think of to need to deploy contantly.

The code for this is here:  
https://github.com/hairizuanbinnoorazman/terraform/tree/main/google

The portion to deploy the bastion host would be here:  
https://github.com/hairizuanbinnoorazman/terraform/tree/main/google/bastion

We don't need to run any further commands on bastion host as of now (maybe in the future, I will research into what tooling to install on bastion host in order to harden it against attackers). As of now, I didn't look too deep into bastion host tooling since I would generally bootstrap and tear down the entire stack within the day.

The next critical piece of thing to cover would be the step on how to install on docker on the server. We would a way for us to inject it via terraform. One approach, especially in the case where we use Google Cloud instances would be to rely on the `metadata_startup_script` - there is service within each instance that would immediately run upon instance startup - which we would want in this case.

```hcl
resource "google_compute_instance" "server" {
  count = var.service_meta[var.component].server_count
  zone  = var.gcp_zone

  ...

  metadata_startup_script =  data.local_file.script.content
  
  ...
}
```

We can simply read of the script from another file rather than putting it all within terraform scripts itself. For the case of docker, it is in the following file: https://github.com/hairizuanbinnoorazman/terraform/blob/main/google/server/scripts/docker. The file would be read via terraform's `local` module which would then have that content be piped into the `google_compute_instance` module when starting our private server.

With that all in place, we can simply run the commands from the `google` folder of the git repo:

```bash
# If not yet initialized:
terraform init

# Convenience function for creating a docker with bastion host
components='["docker"]' add_bastion=true  make plan
```

Accidentally added a bunch of complex features where a make command would be needed. The make command essentially is wrapper around terraform plan; flags such as where the output of the plan would be is already decleared within the makefile. Other variables that need to be declared would also be things like which gcp project we would like to aim this deployment at.

```makefile
gcp_id=$(shell gcloud config get project)
components?=[]
add_bastion?=false

plan:
	TF_VAR_gcp_project_id=$(gcp_id) terraform plan -out=initial.plan -var 'components=$(components)' -var 'enable_bastion=$(add_bastion)'

destroy:
	TF_VAR_gcp_project_id=$(gcp_id) terraform plan -out=destroy.plan -destroy
```

Once the plan is created, we can simply run the command:

```bash
terraform apply initial.plan
```

## What's available

If you see the codebase as of now, it has already been configured to be able to deploy a variety of common tools and services such as nginx, etcd, mariadb. The full list of what's probably capable will be continually updated on the main `Readme.md` page of the git repo.

Eventually, I would cover other cases as well, such as deploying custom golang applications or ruby applications or even python applicaitons into the various environments - everything controlled or handled via terraform. Look forward to that.