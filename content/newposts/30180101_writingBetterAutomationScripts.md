+++
title = "Writing better automation scripts"
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

Data engineering work usually serves to be fundamentally one of the important bits when it comes to report generation in the business. The act of connecting of understanding the data that goes through the business and the need to maintain all the scripts that handle the pulling and merging all of such data makes the job way harder than one can expect. You are not expected to just be a script junkie; you are expected to be an expert at your domain, understanding the different nuances and assumption each line of script imposes on the processing of such data.

Acquiring the initial set of requirements and writing such automation scripts is usually considered the easiest bit. The harder bits are maintainance, upgrades as well as ensuring that the scripts can be deployed to their respective users. If projects are prototyped rather than properly engineering, one can be pretty sure that there would be hiccoughs and plenty of engineering hours (fancy some late nights and overtime?) in order to ensure that the scripts are ready and running.

Let's go several scenarios on some of the more important bits to consider when doing automations at that stage.

## The Beginning

The beginning for most people, departments or even companies would usually mean just writing a script to quickly pull in the numbers and dumping it into an output file. The output file could be a excel file, csv file or other formats with the aim of such files being fed to a vizualization tool off sorts.

Scripts serve to be the greatest blessing and curse at the same of such teams. Due to their flexibility, one can make scripts to essentially automate every aspect of their jobs (Generating that dreaded report every week, downloading reports from email and saving it in some folder on some online storage for the team). As a result of that flexibility, that would mean that scripts can easily become more complex that expected which leads to eventual huge amounts of technical teams for engineers team to handle.

With that, let's see if there are way and methods in order to reduce that debt or make such jobs slightly easier.

Here are some of the ways to do so:

- [Use git to properly manage such automation scripts](#using-git)
- Ensure package versioning is introduced/added
- Comments that explain why rather than what
- Prefer vectorized operations as compared to loops
- Add testing on algorithms
- Decouple data sources from the script
- Designing a proper configuration management for the script
- Automate documentation

### Using Git

Git is not github (Repeat this 3 times to yourself). Most people get their first taste of git via Github and it is quite understandable to relate git to github. However, git is just tool that helps with version control of any text-based related document (it does binary as well but it's not as useful in that regard)

## Survived the initial hell

The initial hell involved the main writing of the scripts. This involves getting your hands dirty with coding the applications. As mentioned, the initial requirements gathering as well as initial versions of the script are the easy bits. Now this next section won't be as important as the parts in initial help but they do definitely help. There's a reason why we are here; we're here to automate everything and if we still have to manually run the tasks, it would mean that there is plenty of parts that can be improved.

- Deploying code on linux machines and putting sudo on it
- Running code as serverless (Functions as a service)
- Using tools such as Airflow to vizually manage tasks 
- Running tasks in a platform (Kubernetes)
