+++
title = "Using Google Tag Manager in React Web Application"
description = ""
tags = [
    "golang",
]
date = "3018-04-04"
categories = [
    "react",
    "web",
    "google analytics",
]
+++

This is going to be a pretty short post but should prove to be useful if you are already familiar with tool.

When one navigates through a normal server rendered website that is utilizing Google Tag Manager or Google Analytics (assuming that is is set up right), as the page loads, it would send a `page view` hit to the Google Analytics server. This is normal familiar behaviour for most people who used the tools.

However, if the website is a single page application, the whole situation completely changes. If one sets up the tracking tool as usual to track page views and if one debugged the entire scenario, the page hits only get fired on initial load. As the user navigates through the website, no other page view hits get fired to the tool. Reason for this is that the new pages don't technically load a web page - so that does not trigger the tracking hits.

Previously, solutions for these included creating virtual page views which is deeply embedded in the application. This kind of requires the development to roughly construct the page view hit which would be fired as a page view although the way its being done; it would be always like firing of tracking hit in response to events.

