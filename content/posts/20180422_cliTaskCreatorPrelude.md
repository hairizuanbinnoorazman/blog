+++
title = "Let's use CLI to create Tasks!!"
description = "CLI to create tasks made with Golang"
tags = [
    "golang",
]
date = "2018-04-22"
categories = [
    "golang",
]
+++

Out of random curiousity and laziness on my part, I decided to create a CLI tool which would allow me to create tasks on task managements websites such as on Asana, and issues in Github/Bitbucket.

I would be writing it in Golang - seeing that it would allow to be build a CLI tool executable without too much trouble. This would mean less work when it comes to distribution (may need to cross compile if necessary) but for now, will be aiming it for people on macs

# Scoping out work

Before starting out on writing out the CLI tool, we would first need to plan out what would be expected of the product:

In our case, we should be able to substitute the platform for the different platforms we are targeting against

* Allow one to create tasks on platform with labels and deadline
* Allow one to list tasks on platform for a specific user
* Allow one to list tasks for a project
* Allow one to create tasks on multiple platforms at the same time
* Allow one to copy tasks across platforms

The struct could be described as follows - we can't load up too many fields as it will make it not inter-operable across multiple task management platforms.

```go
type Task struct {
    Name        string
    Description string
    Label       string
    Deadline    time.Time
}
```

The first platform to target building would be asana before moving on to other platforms.

# Previewing the final tool

I would imagine that the tool could look something like this:  
(Name of tool is still up in arms - haven't decided anything concrete yet)

```bash
# Create task
tasker create -name="This is a test task" -desc="We would need to try building this product properly" -label="low priority"

# List task
tasker list -tool="asana"

# List task for a project
tasker list -tool="asana" -proj="random"

# Create task for multiple platforms at the same time
tasker create -name="This is a test task" -desc="We would need to try building this product properly" -label="low priority" -tool="asana,github"

# Copy task between platforms
# Needs to be amde easier though
tasker cp -originTool="asana" -id="12" -destTool="github"
```

Some of the tasks can be made easier by using some sort of config file to be able to control the behaviour of the tool, although there would make it hard to understand what's happening. Some of the things to think about would be:

* Set a primary tool and list the rest of secondary tools
* Have a setting that would allow one to set whether they would want the issue to be created only on primary tool but not on the secondary tool/vice-versa

# Actual implementation

We will leave the actual implementation, description of the problem on another date in another blog; look forward to it!!
