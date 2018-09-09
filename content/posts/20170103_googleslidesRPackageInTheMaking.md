+++
title = "Googleslides R Package in the Making"
description = "Googleslides R Package in the Making"
tags = [
    "r",
    "rgoogleslides",
]
date = "2017-01-03"
categories = [
    "r",
    "rgoogleslides",
]
+++

![package-image](/20170103_googleslidesRPackageInTheMaking/package-logo.png)

Some time late last year, the Googleslides API was announced by Google. This was a pretty exciting piece of news; one that took so long to come.

{{< ref "/slides-api-announced-by-google/" >}}

With the API now available, everyone who wanted to automate the "presentation slide" work could now effectively make such slides with scripts, thereby removing the last barrier when it comes to presenting data to people. If you had some kind of script that already does a lot of the heavy lifting of manipulating the data from the various data sources into relevant tables, then all you need is to add a few more lines to then be able to send the data straight to slides. (YES!! No more mundane work of changing numbers in monthly slides)

However, it is kind of unfortunate the Google API does not cover all languages (it covers the mainstream languages such as Java and Python though). And R is not included in those languages, which is kind of unfortunate, seeing that R is one of those languages that would largely benefit from having a package that does this magic.

So late last year, I had some fortune in having some free time to put together a small R package that talks to the Googleslides API and here it is!!

https://github.com/hairizuanbinnoorazman/rgoogleslides

It is not on CRAN yet although I plan to tidy it up and move it there as soon as I have more free time to work on this further. (Update: It's not on CRAN: https://cran.r-project.org/web/packages/rgoogleslides/index.html)

So before we end this post, let me quickly go through one of the more major functions within this package.

Let's say we have a monthly presentation slide of 2 slides (This is just an example)

**Title Slide**

![package-image](/20170103_googleslidesRPackageInTheMaking/filledTitle.png)

**Second Slide**

![package-image](/20170103_googleslidesRPackageInTheMaking/teamMembersFilled.png)

So, for each month, you would need to edit the month and year of the slides. It may not be a problem for just 2 slides but imagine if you have a huge slide deck which does monthly report comparisons etc. It will just become a mundane task to update all the information for the slides.

Hence, let's alter the slides this way. Alter the June 2016 to { month-year }

**Title Slide**

![package-image](/20170103_googleslidesRPackageInTheMaking/emptyTitle.png)

**Second Slide**

![package-image](/20170103_googleslidesRPackageInTheMaking/teamMembersFilled.png)

We can now use the Googleslides R package to update the slides.
Get the slide id from the url:

https://docs.google.com/presentation/d/1EtDqjWDXXXXXBYVdAJo/edit#slide=id.g1af69dd764_0_63

Next, download the Googleslides package by following the instruction on Github

```R
install.packages("devtools")
library(devtools)
devtools::install_github("hairizuanbinnoorazman/googleslides", build_vignettes = TRUE)
```

Then, run the following in RStudio:

```R
authorize()
replace_all_text("1EtDqjWDXXXXXBYVdAJo", "June 2016", "{month-year}")
```

Congratulations! You have done up the initial R script on manipulating GoogleSlides using R.

The following method of doing things is inspired from the following tutorial in the Googleslides API documentation:
https://developers.google.com/slides/how-tos/merge#example

The package is still under heavy development and more and more features are being added to make a more impactful package. So, if you found any bugs or if you have any feature requests, just add it in the issues of the repository and I will see if I can absorb the suggestion and implement those features.
