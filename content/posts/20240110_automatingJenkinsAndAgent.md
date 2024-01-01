+++
title = "Connect Slaves Jenkins configured with JCasC - Docker"
description = "Connect Slaves Jenkins configured with JCasC - Docker and Docker Compose"
tags = [
    "jenkins",
    "cicd",
    "docker",
]
date = "2024-01-10"
categories = [
    "jenkins",
    "cicd",
    "docker",
]
+++

This is a continuation of the previous blog post for automating Jenkins server setup. The previous setup only created a setup for a single node Jenkins build server farm. This definitely won't be sufficient for larger teams where they would be building applications and running workflows on a more frequent basis. Refer to the page: [Automating Jenkins Initial Setup](/automating-jenkins-initial-setup)

The next step to try to automate would be the automating of adding worker or agent nodes to the entire cluster. Before going down that route, let's first try to add it in a manual fashion that is extended from our previous step.

Let's first aim to setup the agent on the same machine but have the main/controller and the other worker nodes to be separate docker containers.

## Manually connect Jenkins agent to main Jenkins node

First, we'll need to setup a new docker network - this is to allow the containers to talk to each other.

```bash
docker create network cicd
```

Next step would be create the Jenkins main node

```bash
docker build -t cjenkins .
docker run --name jenkins -p 8090:8080 --network cicd -d cjenkins
```

The `Dockerfile` and the way we would build it is all mentioned in previous post. This post is focusing on how we can connect the agent to the main/controller Jenkins server.

Once we have our Jenkins main controller running, the next step would be to be to set up the steps to manually connect our Jenkins agent. The first step is to click manage Jenkins

![click-manage-jenkins](/20240110_automatingJenkinsAndAgent/jenkins-click-manage-jenkins.png)

The next step would be to click the manage nodes

![click-manage-nodes](/20240110_automatingJenkinsAndAgent/jenkins-click-manage-nodes.png)

We can set then create a node that our main Jenkins main node will be managing.

- Name: zzz
- Number of executors: 1
- Remote root directory: /home/jenkins
- Labels: local
- Usage: Use this node as much as possible
- Launch Method: Launch agent by connecting it to the controller
- Availability: Keep this agent online as much as possible

Once we have configured it, we can then run the following docker Jenkins agent to have that connect to the Jenkins main node.

```bash
docker run --name agent -d --network cicd jenkins/agent java -jar /usr/share/jenkins/agent.jar -url http://jenkins:8080/ -secret <new secret always generated> -name zzz -workDir "/home/jenkins"
```

With that, the Jenkins node should be available for use.

