+++
title = "Restructuring Rgoogleslides"
description = "Moving Rgoogleslides away from wrapped functions"
tags = [
    "r",
    "rgoogleslides",
]
date = "2017-05-10"
categories = [
    "r",
    "rgoogleslides",
]
+++

In the initial draft of the rgoogleslides package, there were several wrapper functions that serve to immediately call the Google Slides API immediately after it is being used. Some of the examples are below:

- replace_text
- create_shape
- create_table

What is happening under the hood is that the function would invoke internal functions that would then first create an R list that would manage requests and add the request details into that list before immediately making the call to the Google Slides API. The idea behind this is to provide the common code that all the functions can use and to also prevent users from being too exposed to computing concepts of passing an "object" around etc. To summarize; the above wrapper functions are to simplify way the package by packaging the API in R functions.

Unfortunately, this would mean that the API is not being utilized to its fullest. With the additional knowledge that we are limited to 40000 API calls a day. ([Link](https://developers.google.com/slides/limits)) , we would need to ensure that we would reduce the number of calls as much as possible, which is why we would need a different way of calling it from R. We need a way to somehow batch the slide request into bigger requests; which would mean a complete restruturing of the Rgoogleslides package.

In the next upcoming release of the rgoogleslides package, the package would involve removing the wrapper functions and provide users access to the request builder functions. A blog post detailing this details would be released soon. Apologies for any breaking changes between the package version.

In the case where you are still dependent on the previous release, the code for that has been tagged accordingly and can still be installed via the following lines of code:

```R
# Install initial version of rgoogleslides
# Initial version has been tagged has v0.1.0-alpha
# Install devtools R package if you have not installed it yet
install.packages("devtools")

library(devtools)
install_github("hairizuanbinnoorazman/rgoogleslides", ref="v0.1.0-alpha")
```
