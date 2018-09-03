+++
title = "Slides API announced by Google!"
description = "Slides API announced by Google!"
tags = [
    "data science",
    "google slides",
    "rgoogleslides",
]
date = "2016-11-19"
categories = [
    "data science",
    "google slides",
    "rgoogleslides",
]
+++

Earlier this year, Google announced a couple of new APIs for the set of Google Products in its productivity and office suite, namely the Google Slides API

https://gsuiteupdates.googleblog.com/2016/05/new-ways-to-keep-data-flowing-between.html

It has been a long time but ever since the announcement in the Google IO earlier this year, I've been anticipating for the arrival of the API and it's already here!!

Google Slides API homepage
https://developers.google.com/slides/

With the following API in place, the workflow for most of data analysis work (at least those who mainly use the Google Apps) can be crafted end to end. In my case, since I mostly use R for my data manipulation work, I can create a workflow that looks something like this:

Extracting data from Google Analytics or Google BigQuery platforms using the R packages, RGA and bigrquery.
Manipulate and summarize the data using dplyr, tidyr and other packages. Possible run machine learning models using caret or its underlying ML packages. Afterwhich, we would then put the learnings into a Google Slides template via the Google Slides API. The slides would be ready to be used for presenting to the audience with less effort as compared to the usual

Although having the new API is great and all; unfortunately there is no R package for the slides API and hence, I am already writing one during my spare time.

Just keep a look out on this blog on future news of the googleslides R package!
