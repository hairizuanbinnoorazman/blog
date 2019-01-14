+++
title = "Devops Tools with Google Cloud Platform"
description = "Using devops tooling to make it easier to deploy applications to Cloud Platforms"
tags = [
    "google-cloud",
]
date = "3019-01-14"
categories = [
    "google-cloud",
]
+++

There are various tooling out there to make deployment of applications easier. Some tools are used in order to help developers and organizations attempt to reach the "12 factor app" standard of applications which are set of applications that are explicitly designed to be able to scale where needed.

Nowadays, many people turn to docker in an attempt to solve some of the goals in 12 factor app designs. (e.g. Using `dockerfiles` which would declaratively mention all dependencies needed by the application and its operations.). This property of requiring dependencies to be declared in files for application would eventually lead to teams requiring to make immutable server images which is where devops tools like Packer and Terraform can help tremendously.

However, let's say that we are restricted from using containers and if we were to rely on only virtual machines in public cloud. What could we depend on?

Let's go through several tools that can help developers achieve this goal:

1. Ansible. A tool that allows developers to declarively configure a server more easily. The ansible allows one to declaratively/implicitly install packages, add configurations files via use of templates files and run admin commands. It is possible to actually run bash scripts to run get all of such settings into the server but shell scripts aren't easy to read and debug and program. It is easier to write scripts but with ansible, the tool comes with a whole bunch of functionality that allows one to declare the require actions to install the required software onto the server.
2. Terraform. A tool that allows developers to create their needed infrastructure on a public cloud. (There are other uses to this tool, but generally, it is used to bootstrap/maintain infrastructure). With the Terraform tool, it allows one to maintain a set of files which describes their application infrastructure. The tool would take the responsibility to ensure that the actual infrastructure matches what is being described in those files.
3. Packer. A tool that creates custom images. When trying to scale applications on the cloud, it is required to create some sort of server template that the cloud can use to create multiple copies of the application for horizontal scalability. In order to help create the server template in a reproducible manner, we can use scripts to create the images (rather than setting up the servers manually and then setting it to be a template that the cloud vendor can use to support scaling needs)

## Case Study: Installing Nginx

Let's set a simple example of using the above devops tools in order to setup a scenario of install Nginx webserver. We would try the example below on the Google Cloud Platform but I would imagine it would relatively be easy to have an AWS version of such configuration files.

### Step 1: Setup of Ansible Scripts

Seeing that it is easier to do server configuration on Ansible as compared to fiddling around with the other two, we would do so. Interestingly, Packer has a Ansible provisioner which can make use of. Refer to the documentation here: https://www.packer.io/docs/provisioners/ansible-local.html

The setup of Ansible would mean installing Python and Ansible on the machine which the command to run the commands.

```yaml
- hosts: default
  become: true

  tasks:
    - name: Install nginx on server
      apt:
        name: "{{ packages }}"
        update_cache: yes
      vars:
        packages:
          - nginx
```

As mentioned, when we are using Ansible, we would want to use remote Ansible so that we don't have the requirement of needing the remote machine to have Python and Ansible installed (they're pretty heavy applications to be installed)

With the ansible script, we can build the layer of setting up Packer that would make use of this ansible scripts. (Naturally, we can have a more complex Ansible script but maybe that is more another time)

### Step 2: Packer wrapping Ansible

We can then have the Packer json file that would make use of the above Ansible file.

```json
{
  "provisioners": [
    {
      "type": "ansible",
      "playbook_file": "./playbook.yml"
    }
  ],

  "builders": [
    {
      "type": "googlecompute",
      "account_file": "account.json",
      "project_id": "",
      "source_image": "debian-9-stretch-v20181210",
      "ssh_username": "packer",
      "zone": "us-central1-a"
    }
  ]
}
```

Do note that configurations are needed for Packer to build the Virtual Machine image. In our case, we would name it `account.json`. We would also need to provide the project id that packer would use to build the image. What would happen under the scenes would be that Packer would contact the GCP APIs; create a temporary VM on Google Cloud Compute. It would then run the Ansible script to config the server and once that is successful, it would save the server as a VM image on the platform, allow you to easily decide between immutable copies of the application.

### Step 3: Terraform to bootstrap Infrastructure

To combine all the above efforts together, the terraform tool is used. This tool makes it relatively easy to declaratively set your required infrastructure. As changes are made to the declarations, the tool would try it's best to sync up the changes between the declared state of the infrastructure and the actual state of the infrastructure of the cloud platform

```conf
variable "project" {}

provider "google" {
  credentials = "${file("account.json")}"
  project     = "${var.project}"
  region      = "us-central1"
  zone        = "us-central1-c"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "f1-micro"

  boot_disk {
    initialize_params {
      image = "packer-1545674155"
    }
  }

  tags = ["http-server"]

  labels = {
    "infra" = "automated"
  }

  network_interface {
    network       = "${google_compute_network.vpc_network.self_link}"
    access_config = {}
  }
}

resource "google_compute_network" "vpc_network" {
  name                    = "terraform-network"
  auto_create_subnetworks = "true"
}

resource "google_compute_firewall" "web-firewall" {
  name    = "web-firewall"
  network = "${google_compute_network.vpc_network.self_link}"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
}
```

As an example, the above config file declares the network/firewalls required, the machine types as well as memory size/cpu requirements. More complex rules can be added such as declaring storing buckets, databases etc.

A more complex example would be provided in this blog in the future.

### Resources

The above set of code snippets is still incomplete; it only covers files that may be of interest for this blog post to cover. To be on the safer side, rely on the codes within the github repo link below:

Refer to the full set of code here:  
https://github.com/hairizuanbinnoorazman/infra-as-code-examples/tree/master/Example1
