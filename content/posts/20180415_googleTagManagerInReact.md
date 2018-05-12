+++
title = "Using Google Tag Manager in React Web Application"
description = ""
tags = [
    "golang",
    "google analytics",
    "google tag manager",
]
date = "2018-04-15"
categories = [
    "react",
    "web",
]
+++

This is going to be a pretty short post but should prove to be useful if you are already familiar with tool.

## Quick intro of normal website tracking

When one navigates through a normal server rendered website that is utilizing Google Tag Manager or Google Analytics (assuming that is is set up right), as the page loads, it would send a `page view` hit to the Google Analytics server. This is normal familiar behaviour for most people who used the tools.

However, if the website is a single page application, the whole situation completely changes. If one sets up the tracking tool as usual to track page views and if one debugged the entire scenario, the page hits only get fired on initial load. As the user navigates through the website, no other page view hits get fired to the tool. Reason for this is that the new pages don't technically load a web page - so that does not trigger the tracking hits.

Previously, solutions for these included creating virtual page views which is deeply embedded in the application. This kind of requires the development to roughly construct the page view hit which would be fired as a page view although the way its being done; it would be always like firing of tracking hit in response to events.

## Google Tag Manager to the rescue?

I'm gonna switch to talking about Google Tag Manager now which is the main tool I look to when it comes to website tracking. It is pretty excellent which allows one to embed tracking/advertisement tags without having the developers adding it at the end of projects. I won't go too deep into the structure and concepts of the Google Tag Manager such as Tags, Triggers and Variables here, however, it is necessary to know this to appreciate the rest of the post.

Within Google Tag Manager, there is a set of predefined trigger called `history change`. This is the one we would need to take note as we delve into how React applications handle page changes in their applications. In React Single Page Applications, we would normally use a library called `React Router DOM` which in turns utilizes the `history` library which is then handled by browser. Read the below webpage for more information.

https://developer.mozilla.org/en-US/docs/Web/API/History_API  

With that in mind, all we need to do is to set up a Google Analytics Tag as usual but instead of the normal trigger of firing off on every single page, we would just need to change it to trigger on every history page. This would be sufficient to get all the required page data into Google Analytics tool.

