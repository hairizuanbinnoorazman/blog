+++
title = "Triggering analytics via Serverless Functions"
description = ""
tags = [
    "python",
]
date = "3018-03-14"
categories = [
    "python",
    "automation",
]
+++

Seeing how functions change the way one looks at compute workloads in terms of products makes me wonder how one/companies can look at their analytics workloads and try to see if it was possible to change the costing model in that direction.

Previously, 1-2 years ago, if one told me that they needed to run some automation scripts written in python or R languages, I would probably stretch my fingers and immediately begin work deploying a Linux compute service. I would manually install all the dependencies needed and proceed to give the required users access to the servers before continuing on my way. This meant that the server would continue to operate continuously. They aren't going to keep shutting it down and then re-asking the engineers to recreate the servers over and over again; it's going to cost more if done that way.

Fortunately, times have changed quite a bit since then. Other automation tools came along (e.g. Ansible, Packer, Terraform), then containers came (e.g. Docker) and now, the big movement from the industry, functions as a services (FAAS).

Let's say if we chose to develop our analytical workload onto FAAS by a cloud provider. Just imagine writing a function and then throwing it to a provider and letting the provider figure out how to run that service. One no longer has to think of how to ensure that the machine provisioned had to be able to take on all the analytical load during that time and even ensuring that the cost of provisioning the machine being kept as low as we possibly can.

However, rather than keep going on how awesome the FAAS model for running workloads is, let's have a sample application workload that we can work with.
