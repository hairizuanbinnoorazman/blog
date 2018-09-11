+++
title = "Rgoogleslides Updated to v0.2.0-alpha"
description = "Restructured rgoogleslides. Updated to v0.2.0-alpha"
tags = [
    "r",
    "rgoogleslides",
]
date = "2017-05-11"
categories = [
    "r",
    "rgoogleslides",
]
+++

The rgoogleslides package is being upgraded with a quite a big change in methodogy. Refer to the following release notes for more detailed information.

https://github.com/hairizuanbinnoorazman/rgoogleslides/releases/tag/v0.2.0-alpha

The previous design package suffer from several design flaws, some of which would be detailed below:

Wrapper functions that wrap internal builder functions. The concept behind this is nice as it lowers the barrier of entry of using the package. A quick survey of the possible users of the package mention about how they are more familiar with using ordinary R functions and that they wouldn't want to fiddle with complex R objects which was why the wrapping functions were created.

However, the wrapper functions would mean duplicate efforts as well as poor usage of API limits. Refer to the previous [post]({{< ref "20170510_restructuringRgoogleslides.md" >}}) and this might make it more difficult to maintain the package in the future.

Hence, the wrapper functions have been dropped. We would use R objects to hold all the information that would be needed to pass to Google Slides API.

At the same time, having wrapper functions could potentially lead to inefficient use of the Googleslides API. This was mentioned above. The API is restricted by the number of calls to the service but yet we are _underloading_ each call to the service. Each call can potentially take in tens of update changes that is to be made to the slides but the wrapper functions would only send only a few at one time due to the way its designed.

Handling of lists in the function make it difficult to validate that the right R object is being passed around to each of the functions. This was why several R6 objects were used; namely the GoogleSlidesRequest object as well as the PagePropertyElement object.

This version can be called via the following code:

```R
# Install initial version of rgoogleslides
# Current version has been tagged has v0.2.0-alpha
# Install devtools R package if you have not installed it yet
install.packages("devtools")

library(devtools)
install_github("hairizuanbinnoorazman/rgoogleslides", ref="v0.2.0-alpha")
```
