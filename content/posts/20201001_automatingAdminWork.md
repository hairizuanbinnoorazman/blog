+++
title = "Automating the admin work when organizing webinars in a meetup group"
description = "Automating the admin work that goes behind the scene when organizing webinars"
tags = [
    "golang",
]
date = "2020-10-01"
categories = [
    "golang",
]
+++

There is actually plenty of work that needs to be done in order to continuously and consistently organize webinars in a meetup group. I am involved in one of them and it takes quite a bit of effort to maintain such effort to ensure that the group look "alive" with webinars being continuously churned out during this unique situation.

Before delving into the automation tool being built, it might be good to explore what needs to be done on a per webinar basis:

- Create webinar event on streaming platform
- The group happens to be on Meetup.com. Naturally, the event needs to be added the platform to get people to know about the event
- Create the calendar invite for organizers and speakers. Mainly to get everyone's time to synced up for the live webinar event

A problem that often comes up is that the webinar details are usually quite vague until quite close to webinar date (details are only confirmed within the week - more for optimistic cases). In the case where we would want to ensure that the details of the events are in sync between the streaming platform and meetup.com, we would kind of waste a bit each time we would want to add new updates to the event.

It's kind of a pain to do after a while so naturally, one or two of the platform will not be updated in time, thereby reducing the "marketing" of the webinar which kind of leads to less interest garnered for the webinar.

## Radical idea - Automating this thing

I didn't exactly want to spend my free time updating various platform as planning for a webinar goes on. Rather than that, wouldn't a tool that does syncing be nice to have here?

And that's what is being trialed right here:  
https://github.com/hairizuanbinnoorazman/techmeetup

The tool is built with heavy inspiration from how kubernetes does things. We have some files that we would use that would serve as our primary reference. Every hour, the tool would check against primary reference, then check against the "target platforms", in this case, the streaming platforms as well as the meetup. We would do a GET request and check that whatever is on the platform coincides what is defined in the primary reference. Else, we would do an update of the details.

The tool kind of fulfils my goals:

- Allow me to pass the syncing job to the tool and let it handle, allowing me to achive a "always" updated
- Explore the various APIs and Google APIs and Auth and see how they can all work together

Unfortunately, the tool is still young (and with that, expect bugs) - so I wouldn't expect it to handle the more "critical" webinars. But for the more regular meetups, it should generally be ok for the automation to handle it.

## The ROADMAP forward

I've got plenty of ideas then I want to stuff into the tool - that kind of allow me to focus on the actual thing that can bring benefit to the community - which is content. Some of the things I kind of want the tool to handle:

- Information Consolidation. The community held a whole bunch of events and got a whole bunch of speakers down to bring in content. The scarce resource here is speakers and as much as possible we would hold onto speaker details in the hopes that if we need speakers for future events, we can invite them over for such events
- Utilize other social media platforms. It's unfortunate that the meetup group I'm involved in is not in the various social media groups. There is a few reasons for this - it's painful to keep using it; it's easy for disused accounts to be hacked (I'm looking at you twitter).

I will probably come up with more ideas as I continue to work on the tool.
