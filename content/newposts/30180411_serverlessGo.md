+++
title = "Trying out Go on the Serverless framework"
description = ""
tags = [
    "golang",
]
date = "3018-04-11"
categories = [
    "golang",
    "serverless",
    "tool",
]
+++

AWS released the Golang support late last year and serverless kind of immediately got onto the bandwagon of providing a framework to aid in deploying such serverless applications. I wrote a blog post in the past in regards to attempt to deploy such serverless applications and its a genuinely difficult thing to do; if one does the serverless application using python and if they needed some sort of library that kind of depends on c bindings, you would need to run docker containers and all in order to get and install the libraries and binaries which would then be used to deploy the application.

I expect Go to face the same issue; the need to cross compile it down accordingly to the right os; if you need some sort of web server, then you would need to create the api gateway to connect the serverless application to the internet etc. It would still continue to remain a pain to deploy. Processes need to be in place to reduce the amount of pain to go through when deploying such serverless applications.

# What should we build?

Let's build an application that uses the Github API to analyze the list of Github issues in an repo and tag it accordingly. In some of the bigger repos out there, there could easily be many issues that can be overlooked by the author or the core team so we would some sort of automated system to assist in managing such issues.

Let's set up the following rulesets:
- If issue is a week old (use the @ symbol to try to inform the user to provide additianal information regarding the issue. It could be possible that the core maintainers do not understand the use case and problems raised in that issue)
- If issue is 1 month old. Set a tag to `old issue`
- If issue is 2 months old. Close the issue
- Send a daily report of number of issues > 2 weeks old, number of issues > 1 month old. 