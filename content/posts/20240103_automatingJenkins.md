+++
title = "Automating Jenkins Initial Setup"
description = "Automating Jenkins Initial Setup using Configuration as Code"
tags = [
    "jenkins",
    "cicd",
    "docker",
]
date = "2024-01-03"
categories = [
    "jenkins",
    "cicd",
    "docker",
]
+++

Jenkins, a pretty popular Continuous Integration/Continuous Deployment (CI/CD) build tool, plays a pivotal role in automating the software development/deployment process. Over the years, Jenkins has evolved to become an extremely versatile automation server that facilitates continuous integration and delivery by orchestrating the building, testing, and deployment of code. Its extensibility through a vast array of plugins makes it adaptable to various environments and development workflows.

The initial configuration of Jenkins can pose challenges and is usually done in a manual manner. The manual nature of why its done that way is due to the way Jenkins grew over the years - previously, the whole concept of being able to configure entire IT infrasturucture that powers our app doesn't exist. Only when tools such as Ansible and Terraform appeared on the scene did this concept become a pretty popular one. However, with something like Jenkins, which is run by numerous companies in the world, it's important for them not to break anything - so they have to move slow when attempting to introduce any crazy new changes.

Although it's now somewhat possible to automate parts of initial Jenkins setup - it's still pretty clunky. Hence, before we venture down that janky path, we would need to understand why the automating of setup of Jenkins is crucial in simplifying the management of CICD platforms for company. A janked/hacked system is usually a recipe for disaster for most teams since someone would eventually need to support that hack and they've got to also find new ways of doing the same thing in the case the software gets updated to the point that the hack goes way.

Once we automate the setup of Jenkins, it will now make it trivial to simply "toss out" the old server and recreate a new one since the whole thing is already codified. There is no/less fear to bootstrap or move Jenkins servers around since it can be simply be recreated from scratch.

## Automating Jenkins Initial Configuration

I will be providing an example of a way to setup Jenkins in an automated way within a docker image. For this simple use case, I will simply be providing an extremely simple setup - it simply just echo out stuff. We won't be covering things such as setup Jenkins slave etc or running Jenkins job within a docker runner etc.

As mentioned above, Jenkins is usually manually configured. Here are the list of things that we would need to do if we didn't automate it:

- Installing the relevant Jenkins plugins that we would use for our instance.
- Define pipelines that we would be able to use. Within Jenkins, we can point the pipelines to specific git repositories which can read Jenkinsfile (the pipeline definition file) that we can use for building our applications/run tasks on our infrastructure.

Here is the repo and directory that will demonstrate this: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Environment/jenkins  
Do take note that the repo will continually update as time goes by - so there might be stuff within that repo that might not align so well with the contents in this blog.

First, we would need a Dockerfile - within the Dockerfile, we would need to run the step install plugins.

```Dockerfile
FROM jenkins/jenkins:latest
COPY plugins.txt /var/jenkins_home/plugins.txt
RUN /bin/jenkins-plugin-cli -f /var/jenkins_home/plugins.txt
```

One of the important plugins that we would need to use would be the configuration as code (which is what we would want to do here). We should add that in plugins.txt. A large majority of the plugins listed in `plugins.txt` is the "default" set of plugins that is recommended to install if we went through the startup wizard during mnaual setup of Jenkins.

```text
ace-editor
apache-httpcomponents-client-4-api
authentication-tokens
blueocean
blueocean-autofavorite
blueocean-bitbucket-pipeline
blueocean-commons
blueocean-config
blueocean-core-js
blueocean-dashboard 
blueocean-display-url
blueocean-events
blueocean-git-pipeline
blueocean-github-pipeline
blueocean-i18n
blueocean-jwt
blueocean-personalization
blueocean-pipeline-api-impl
blueocean-pipeline-editor
blueocean-pipeline-scm-api
blueocean-rest
blueocean-rest-impl
blueocean-web
bootstrap5-api
branch-api
caffeine-api
checks-api
cloudbees-bitbucket-branch-source
cloudbees-folder
credentials
credentials-binding
display-url-api
durable-task
echarts-api
favorite
font-awesome-api
git
git-client
github
github-api
github-branch-source
handy-uri-templates-2-api
htmlpublisher
jackson2-api
javax-activation-api
javax-mail-api
jaxb
jenkins-design-language
jjwt-api
jquery3-api
jsch
junit
mailer
matrix-project
role-strategy
okhttp-api
pipeline-build-step
pipeline-graph-analysis
pipeline-groovy-lib
pipeline-input-step
pipeline-milestone-step
pipeline-model-api
pipeline-model-definition
pipeline-model-extensions
pipeline-stage-step
pipeline-stage-tags-metadata
plain-credentials
plugin-util-api
popper2-api
pubsub-light
scm-api
script-security
snakeyaml-api
sse-gateway
ssh-credentials
structs
token-macro
trilead-api
variant
workflow-api
workflow-basic-steps
workflow-cps
workflow-durable-task-step
workflow-job
workflow-multibranch
workflow-scm-step
workflow-step-api
workflow-support
configuration-as-code
```

The next step would be to provide a yaml file that we can define some of the properties of the Jenkins. And another thing that we would need to do is also to tell Jenkins to skip the initial setup of the Jenkins server.

```Dockerfile
FROM jenkins/jenkins:latest
COPY plugins.txt /var/jenkins_home/plugins.txt
RUN /bin/jenkins-plugin-cli -f /var/jenkins_home/plugins.txt
COPY jenkins.yaml /var/jenkins_home/jenkins.yaml
ENV JAVA_OPTS "-Djenkins.install.runSetupWizard=false ${JAVA_OPTS:-}"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/jenkins.yaml
```

This would be the configuration file that we would pass for configuration as code for Jenkins

```yaml
jenkins:
  systemMessage: Jenkins managed via Configuration as Code
  securityRealm:
    local:
      allowsSignup: false
      users:
       - id: admin
         password: password
  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: "admin"
            description: "Jenkins administrators"
            permissions:
              - "Overall/Administer"
            entries:
              - user: "admin"
          - name: "readonly"
            description: "Read-only users"
            permissions:
              - "Overall/Read"
              - "Job/Read"
            entries:
              - user: "authenticated"
  crumbIssuer: "standard" 
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: SYSTEM
              id: admin
              username: admin
              password: password
```

With this, we can kind of start a Jenkins but it has no jobs that we can use. We should look further into this.

## Introduce Jobs and Pipelines in our Configured Jenkins

To make our initially configured Jenkins useful, we would need to have it immediately have some pipelines jobs that we can immediately use. There are 2 things that we would need here:

- Have a Jobs DSL plugin installed on our Jenkins setup. We would then need to define the jobs to create pipelines. We would then set the jobs to be run from our configuration as code Jenkins configuration. This is needed since there doesn't seem to be way to define pipelines straight from configuration as code.
- Create Jenkinsfile that would define our pipeline jobs that we would be using on our Jenkins server

For the most simplest job - we would be loading a "job" that will define the pipeline in our docker image. It will not require to referring to other git systems to pull in any Jenkinsfile. For the Jenkinsfile, we will simply run echo commands:

```Jenkinsfile
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                echo 'Building..'
            }
        }
        stage('Test') {
            steps {
                echo 'Testing..'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying....'
            }
        }
    }
}
```

To define this pipeline, we would need the following job definition.

```groovy
String fileContents = new File('/home/pipelines/firstjob.Jenkinsfile').text
pipelineJob("firstjob") {
    parameters {
        stringParam('name', "", 'name of the person')
    }
    definition {
        cps {
            script(fileContents)
            sandbox()
        }
    }
}
```

We would then need to install the `jobs-dsl` plugin as well as add the above files in Dockerfile

```Dockerfile
FROM jenkins/jenkins:latest
COPY plugins.txt /var/jenkins_home/plugins.txt
RUN /bin/jenkins-plugin-cli -f /var/jenkins_home/plugins.txt
COPY jenkins.yaml /var/jenkins_home/jenkins.yaml
ENV JAVA_OPTS "-Djenkins.install.runSetupWizard=false ${JAVA_OPTS:-}"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/jenkins.yaml
COPY jobs /home/jobs
COPY pipelines /home/pipelines
```

For the plugin text file

```text
ace-editor
apache-httpcomponents-client-4-api
authentication-tokens
blueocean
blueocean-autofavorite
blueocean-bitbucket-pipeline
blueocean-commons
blueocean-config
blueocean-core-js
blueocean-dashboard 
blueocean-display-url
blueocean-events
blueocean-git-pipeline
blueocean-github-pipeline
blueocean-i18n
blueocean-jwt
blueocean-personalization
blueocean-pipeline-api-impl
blueocean-pipeline-editor
blueocean-pipeline-scm-api
blueocean-rest
blueocean-rest-impl
blueocean-web
bootstrap5-api
branch-api
caffeine-api
checks-api
cloudbees-bitbucket-branch-source
cloudbees-folder
credentials
credentials-binding
display-url-api
durable-task
echarts-api
favorite
font-awesome-api
git
git-client
github
github-api
github-branch-source
handy-uri-templates-2-api
htmlpublisher
jackson2-api
javax-activation-api
javax-mail-api
jaxb
jenkins-design-language
jjwt-api
jquery3-api
jsch
junit
mailer
matrix-project
role-strategy
okhttp-api
pipeline-build-step
pipeline-graph-analysis
pipeline-groovy-lib
pipeline-input-step
pipeline-milestone-step
pipeline-model-api
pipeline-model-definition
pipeline-model-extensions
pipeline-stage-step
pipeline-stage-tags-metadata
plain-credentials
plugin-util-api
popper2-api
pubsub-light
scm-api
script-security
snakeyaml-api
sse-gateway
ssh-credentials
structs
token-macro
trilead-api
variant
workflow-api
workflow-basic-steps
workflow-cps
workflow-durable-task-step
workflow-job
workflow-multibranch
workflow-scm-step
workflow-step-api
workflow-support
configuration-as-code
job-dsl
```

For the configuration as code jenkins yaml file.

```yaml
jenkins:
  systemMessage: Jenkins managed via Configuration as Code
  securityRealm:
    local:
      allowsSignup: false
      users:
       - id: admin
         password: password
  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: "admin"
            description: "Jenkins administrators"
            permissions:
              - "Overall/Administer"
            entries:
              - user: "admin"
          - name: "readonly"
            description: "Read-only users"
            permissions:
              - "Overall/Read"
              - "Job/Read"
            entries:
              - user: "authenticated"
  crumbIssuer: "standard" 
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: SYSTEM
              id: admin
              username: admin
              password: password
jobs:
  - file: /home/jobs/firstjob.groovy
```

This should allow us to have a Jenkins docker image that immediately have `first job` on initial login.

## Adding a second job

Let's add another job that will pull the Jenkinsfile from a repo. This would probably be more typical of some of the process - if we update Jenkinsfile, there is no need to recreate docker image for Jenkins - our pipeline should simply pull the new configuration for the pipeline without too much issue.

```yaml
jenkins:
  systemMessage: Jenkins managed via Configuration as Code
  securityRealm:
    local:
      allowsSignup: false
      users:
       - id: admin
         password: password
  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: "admin"
            description: "Jenkins administrators"
            permissions:
              - "Overall/Administer"
            entries:
              - user: "admin"
          - name: "readonly"
            description: "Read-only users"
            permissions:
              - "Overall/Read"
              - "Job/Read"
            entries:
              - user: "authenticated"
  crumbIssuer: "standard" 
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: SYSTEM
              id: admin
              username: admin
              password: password
jobs:
  - file: /home/jobs/firstjob.groovy
  - file: /home/jobs/secondjob.groovy

unclassified:
  # scmGit:
  #   addGitTagAction: false
  #   allowSecondFetch: false
  #   createAccountBasedOnEmail: true
  #   disableGitToolChooser: false
  #   globalConfigEmail: jenkins@domain.local
  #   globalConfigName: jenkins
  #   hideCredentials: true
  #   showEntireCommitSummaryInChanges: true
  #   useExistingAccountWithSameEmail: false
  location:
    url: http://localhost:8090
    adminAddress: admin@jenkins.com
```

For the second job to create the second job

```groovy
pipelineJob("secondjob") {
    parameters {
        stringParam('name', "", 'name of the person')
    }
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://github.com/hairizuanbinnoorazman/Go_Programming')
                    }
                    branch('master')
                }
            }
            scriptPath('Environment/jenkins/pipelines/secondjob.Jenkinsfile')
        }
    }
}

```

For testing purposes, we can simply copy and paste the secondjob.Jenkinsfile from firstjob.Jenkinsfile.

Also, another thing that we would need to do would also be set and configure the git tool within the Jenkins docker server

```Dockerfile
FROM jenkins/jenkins:latest
COPY plugins.txt /var/jenkins_home/plugins.txt
RUN /bin/jenkins-plugin-cli -f /var/jenkins_home/plugins.txt
COPY jenkins.yaml /var/jenkins_home/jenkins.yaml
ENV JAVA_OPTS "-Djenkins.install.runSetupWizard=false ${JAVA_OPTS:-}"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/jenkins.yaml
RUN git config --global user.email "you@example.com" && \
    git config --global user.name "Your Name"
COPY jobs /home/jobs
COPY pipelines /home/pipelines
```

With those files, now, we can have Jenkins server that has 2 possible jobs that we can use to run simple "echo" jobs. 

I will probably dive deeper into this setup to see how else we can extend the functionality of such automated Jenkins setup.
