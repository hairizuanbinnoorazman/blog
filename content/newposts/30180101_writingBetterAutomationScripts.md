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

- [The Beginning](#the-beginning)
    - [Using Git](#using-git)
    - [Package versioning](#package-versioning)
    - [Proper Commenting](#proper-commenting)
    - [Vectorized Operations](#vectorized-operations)
    - [Testing Algorithms](#testing-algorithms)
    - [Decoupled Data Sources](#decoupled-data-sources)
    - [Proper Config Management](#proper-config-management)
    - [Automate Documentation](#automate-documentation)
- [Survived the initial hell](#survived-the-initial-hell)

### Using Git

Git is not github (Repeat this 3 times to yourself). Most people get their first taste of git via Github and it is quite understandable to relate git to github. However, git is just tool that helps with version control of any text-based related document (it does binary as well but it's not as useful in that regard). Once one install git, you can use `git init` and with that, you've kind of have yourself a local repository that you can play around and control.

With git, we can do experimentation with the code base. This is done by branching our code and testing our changes and assumptions on alternative branches. If those tests turn out faulty or the assumptions that we have are wrong, we could just as easily revert it back.

### Package versioning

Package versioning is one of those problems that is not a problem until you get bitten by one of those versioning problems; but once you get bitten, it is really painful to recover from. You can probably feel such pains by volunteering to upgrade a 5-7 year old django or ruby or rails that have not been touch or undergo heavy maintainance. I swear you will definitely feel like rage quiting half way through.

Part of the problem of attempting to upgrade such applications is that different versions of packages used by applications would result in some packages having conflicting versions.

Let's have an example of a web application requiring the following dependencies:

- package A (v1.0.0) -> dependant on package C (v0.1.0)
- pacakge B (v1.0.0) -> dependant on package C (v0.1.0)

Let's say we found out that there is an update in package A which requires an upgrade for package C.

- package A (v1.1.0) -> dependant on package C (v0.2.0)
- pacakge B (v1.0.0) -> dependant on package C (*v0.1.0*)

Now, package B would also need to upgrade since its also dependant on package C. But what if the scenario is such that package B's author has not been upgrading that package and it the upgrade of version 0.2.0 of package C causes failure to package B. Now there's a conflict in package added to the project.

Imagine this on the scale of an app where there could be hundreds of packages and each of packages have their dependencies; the problem now has become an exponential one.

When it comes to languages like Python, there are various tools that handle this. The `requirements.txt` file was one of the better ways of doing it but ever since the `pipenv` package came out, that method is definitely the better way of handling package versioning in a project. Further details won't be available here but in a another blog post.

### Proper Commenting

Comments are generic way of adding context to codebases. Sometimes, due to structures of code, comments are used to explain what that section is trying to do. Unfortunately, using comments this way is not the most effective way of using them - when code needs comments in order to explain what it's trying to do, its a sign that there is a need to do some sort of abstraction on that section of the script; e.g. breaking that section out into a separate function.

Instead, it is much more vital to actually use comments to explain **why** a certain section of code was introduced. People usually get the what of code, and this is generally read from the code itself rather than trusting the comment section blindly. The **whys** allows one to understand more context of why the code base on designed in a certain way.

Some example comments could be:

```python
def a_random_function(random_number):
    """
    Checks and returns a corrected ID from the database
    :param random_number: An integer that is the ID of the record being checked
    :type random_number: int
    :returns: An integer representing the corrected ID for reference
    """
    # Refer to #182. Check for random number more than 82 is necessary as the database did not record values for that record ID
    # Closest match for this was to record 72 which would have returned 77
    if random_number > 82:
        return 77
    else:
        return random_number + 5
```

With the above comment, we now understand why the comment was added that. We would have eventually understand what the function is doing from the function documentation but we wouldn't know why the random number has a condition check for more than 82 there unless context was provided.

### Vectorized Operations

--Example Text--

### Testing Algorithms

--Example Text--

### Decoupled Data Sources

--Example Text--

### Proper Config Management

--Example Text--

### Automate Documentation

--Example Text--

## Survived the initial hell

The initial hell involved the main writing of the scripts. This involves getting your hands dirty with coding the applications. As mentioned, the initial requirements gathering as well as initial versions of the script are the easy bits. Now this next section won't be as important as the parts in initial help but they do definitely help. There's a reason why we are here; we're here to automate everything and if we still have to manually run the tasks, it would mean that there is plenty of parts that can be improved.

- Using docker to package the solution up
- Deploying code on linux machines and putting sudo on it
- Running code as serverless (Functions as a service)
- Using tools such as Airflow to vizually manage tasks 
- Running tasks in a platform (Kubernetes)
