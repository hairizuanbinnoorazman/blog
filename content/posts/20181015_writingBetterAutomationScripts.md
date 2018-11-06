+++
title = "Writing better automation scripts"
description = ""
tags = [
    "python",
]
date = "2018-10-15"
categories = [
    "python",
    "automation",
]
+++

Data engineering work usually serves to be fundamentally one of the important bits when it comes to report generation in the business. The act of connecting of understanding the data that goes through the business and the need to maintain all the scripts that handle the pulling and merging all of such data makes the job way harder than one can expect. You are not expected to just be a script junkie; you are expected to be an expert at your domain, understanding the different nuances and assumption each line of script imposes on the processing of such data.

Acquiring the initial set of requirements and writing such automation scripts is usually considered the easiest bit. The harder bits are maintainance, upgrades as well as ensuring that the scripts can be deployed to their respective users. If projects are prototyped rather than properly engineering, one can be pretty sure that there would be hiccoughs and plenty of engineering hours (fancy some late nights and overtime?) in order to ensure that the scripts are ready and running.

Let's go several scenarios on some of the more important bits to consider when doing automations at that stage.

- [The Beginning](#the-beginning)
    - [Using Git](#using-git)
    - [Package versioning](#package-versioning)
    - [Proper Commenting](#proper-commenting)
    - [Vectorized Operations](#vectorized-operations)
    - [Decoupled Data Sources](#decoupled-data-sources)
    - [Testing Algorithms](#testing-algorithms)
    - [Proper Config Management](#proper-config-management)
    - [Automate Documentation](#automate-documentation)
- [Survived the initial hell](#survived-the-initial-hell)

## The Beginning

The beginning for most people, departments or even companies would usually mean just writing a script to quickly pull in the numbers and dumping it into an output file. The output file could be a excel file, csv file or other formats with the aim of such files being fed to a vizualization tool off sorts.

Scripts serve to be the greatest blessing and curse at the same of such teams. Due to their flexibility, one can make scripts to essentially automate every aspect of their jobs (Generating that dreaded report every week, downloading reports from email and saving it in some folder on some online storage for the team). As a result of that flexibility, that would mean that scripts can easily become more complex that expected which leads to eventual huge amounts of technical teams for engineers team to handle.

With that, let's see if there are way and methods in order to reduce that debt or make such jobs slightly easier.

Here are some of the ways to do so:

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
- pacakge B (v1.0.0) -> dependant on package C (_v0.1.0_)

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

When one starts programming for the first time, the usual way of having a piece of code run across each item in a set of items would be to use loop. In our case, we can imagine each row of a dataframe (this term can be appied across both R and Python) as an item in a set of items (a set of rows together forms a dataframe). Looping works fine across smaller dataframes and it appear easier to understand but when there is huge amounts of manipulation needed for each dataframe, one can get easily confused.

Let's have a naive example. Let's say we would want to add a new column to a dataset that adds two columns together.

This is via loops

```python
import pandas as pd

df = pd.read_csv("initial.csv")
# Let's assume that the new column is in column 5
df['newColumn'] = 0
for i in range(0, len(df)):
  df.iloc[4, i] = df.iloc[3, i] + df.iloc[2, i]
```

This is via python's pandas apply

```python
import pandas as pd

df = pd.read_csv("initial.csv")
df['newColumn'] = df.apply(lambda x: x['columnTarget1'] + x['columnTarget2'], axis=1)
```

Compare the two above, the latter code is more succint and to the point. Setting up loops makes it really hard to read the code and the focus of the code would become one where there is a need to have the maintainer of the script ensure that the loops are set up right. The natural naive approach is to go with the former where one just loops over the rows whereas the latter approach is harder to understand conceptually but once understood, it becomes way easier to read and debug.

This leads to my point about vectorized operations. In the former piece of python code, having code that loops, fetch the data by index, manipulates them accordingly and then put the value back to the dataframe by index. Most of the work to do this is on the python level which means that is a limit to how fast it can go. The loop can only work on one item at a time. If you think about it on a naive level, how would you want the operation be done faster? Ideally we would want the work to be done on multiple items at the same time in a parallel fashion.

This is where vectorized operations kind of come in. To put it simply, vectorized operations is computation done on an array instead of an item at where one time. Refer to this link on wikipedia: https://en.wikipedia.org/wiki/Array_programming

When we use functions provided in pandas (under the hood it uses numpy), it would actually have that operation vectorized which means we can do our computation work way faster. Try proving to yourself by creating a huge dataset and then attempt to manipulate the dataset via loops and via the functions that pandas offers; you will see that pandas outperforms the loop based approach especially if the datasets get bigger.

Hence, as much as possible, if you are already using the pandas library, just go ahead and utilize as much of the functions that pandas provide until it is really impossible to do so with it. (It is really hard to do so, there are a whole bunch of functions that you wouldn't even imagine it being within the library)

One common case that often come up is that we would need to add data across rows but there for one of the rows, the data that we would need to use to add it is in the previous row. If you think about it, with the row based and column based ways of how calculations are done in pandas, it would appear as though it would impossible to do calculations unless one can specify how to have to refer to the previous row for row-wise calculation. However, an interesting way to see it is that all we need to do is to pull the data downwards by 1 row and then handle the cases when the data is not available. This can be done by the lag/lead methods available in pandas library in python and dplyr library in R.

### Decoupled Data Sources

This is the one pain point that is not completely obvious to people when they create the initial versions of the data automation processing scripts. Most of the time, scripts that automate data processing don't last very long; such scripts are used to solve a temporary problem and once the problem is kind of "solved", it is then handed over to proper engineering teams who would re-engineer it for proper use.

However, what if the situation is one where you are the one who has the maintain the scripts for long periods of time. What would you need to consider?

A few things can easily come to mind:

- Data sources that change across time. Maybe the initial prototypes were done via csv files that some manager in the company. However, the frequency where the manager who has access to the data is too slow and you would want to get faster and more frequent access to the data. The database access is provided to you. Now the problem becomes how to make sure that the data being pulled out does not result in your automation scripts breaking. There would be plenty of checks just to ensure that the right data and the right form is coming in.
- Ensuring that the data sources has the right set of columns for use. This means testing the data to ensure certain columns exist for manipulation further down the line. This is especially important when data sources go through "human hands". The worst form of data sources are one that manually and lovingly constructed by people. Part of the reason of why this happen is naiveness. People assume scripts are robust enough to be able to handle column changes and addition of columns etc but that is where most scripts start to fail. Even shifting the column order can easily break scripts that rely on index numbers etc.

One way to combat this problem is to write the script which abstracts the reading of the data sources out from the main algorithmic part of the script. So instead of just writing this:

```python
import pandas as pd

data = pd.read_csv("some-sample.csv")
data = data.groupby('A').sum()
```

This is where we are putting a few assumptions already. It is assumed that the data being loaded in from `some-sample.csv` already has column and still has column A. (This may not be true. A rename of this would already break this)

We can instead write logic to check that the data would contain certain parameters etc but it would begin to pollute the main script even further.

I will provide another blog post on how to do this effectively.

- Decoupling data sources R (Coming soon)
- Decoupling data sources Python (Coming soon)

### Testing Algorithms

After having all the above in place, we would begin to write algorithms. This is would be heart and meat of our script. This would be where we would encode our business logic and express how the data is to be manipulated in order for us to get the findings that we would need to decide the next move for the business.

Algorithms that are written need to be tested, especially for the corner cases that we would expect; we would need to write a whole bunch of test cases and we somehow need to make it easier to add additional test cases in the future should the need arises.

In the golang community, there is a interesting concept called table driven tests; it involves setting up an array like structure which one can easily append additional records to it to set new test cases. The test would involve going through each of the test case and check against each one of them to see if the response of the algorithms meets the required spec that we would specify.

I will provide another blog post of an example of how to do this effectively.

- table driven tests in Python
- table driven tests in R

### Proper Config Management

Every data script has its own set of ways to allow for script configuration. Some scripts are written in a sophisticated manner such the script exposes a command line tool which takes a configuration flags as input. This configuration flags affects the runtime behaviour of the script.

Alternatively, another way of how one could possibly control the runtime of such scripts is to have it read configuration files. Common configuration files are json, yaml and even text based files but in the case of data manipulation, sometimes, one would need to provide data mapping files (which you can consider it as some sort of configuration file as well.)

One of the worst ways of doing configurations is to do it in a format which doesn't allow you to track changes between versions of configuration managements. Text based configuration files are fine; e.g. csv, text, json and yaml files. However, if one uses binary based formats, it makes it really really hard to replicate and reproduce configurations and the various script runs.

One may think: "Is managing config management that important?" and my answer to that is to try maintaining a script where there is no single source of truth of configurations. It makes hard and almost close to impossible to ensure to replicate that same exact configuration which would produce the error that the user of the script described before. If one uses tools that provide some sort of versions (or named versioning), it would allow it to be much easier to handle such issues.

By default text based formats are immediately ok for use once it is coupled together with git. One can checkin such configuration files which can be maintained and managed accordingly with easy retrieval. (E.g. You can create a new branch for each new configuration? - different run == different script?)

Also, equally important is not only to know the exact configuration of configuration to replicate and reproduce a specified run but to only to understand how the configuration requirements changes across time. Knowing this would allow a developer to understand some of the underlying assumptions when designing the configuration (the awkward keys in the configuration) being there etc

### Automate Documentation

A common way of how people document the coding process is **not to do it** but rather to do it as an after thought. It is sometimes done during handover process or on request by some manager etc. Doing documentation this way makes it such a dreaded process. Yet it such an important process but when it is done months after the coding work is done or on request, there are going to gaps in the knowledge being captured in the documentation.

After being in the field for quite a while, I am of the opinion that code documentation should never be created in a separate tool or even in a separate document. Documentation should be put together with the codebase. This would kind of ensure that as code gets updated, the documentation should be updated as well. Processes can then be put in to ensure that every code change that alters the definition and functionality would require a documentation change.

I will provide several set of blog posts on how to do it the various languages:

- R Documentation Generation (Coming soon)
- Python Documentation Generation (Coming soon)

However, let's say that the above documentation generation are ones that other members of the team is not appreciative of. They would want to have something where they themselves can contribute as well. Although it is tempting to start using document editors such as Microsoft Word or sth, it would still prove to be a bad choice in the long run. Part of the reason is that code bases evolve along time. This would mean documentation would also need to evolve along side it.

## Survived the initial hell

The initial hell involved the main writing of the scripts. This involves getting your hands dirty with coding the applications. As mentioned, the initial requirements gathering as well as initial versions of the script are the easy bits. Now this next section won't be as important as the parts in initial help but they do definitely help. There's a reason why we are here; we're here to automate everything and if we still have to manually run the tasks, it would mean that there is plenty of parts that can be improved.

- Using docker to package the solution up
- Deploying code on linux machines and putting cron on it
- Running code as serverless (Functions as a service)
- Using tools such as Airflow to vizually manage tasks
- Running tasks in a platform (Kubernetes)
