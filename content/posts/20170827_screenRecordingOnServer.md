+++
title = "Screen Recording on the Server"
description = "Screen Recording on the Server"
tags = [
    "python",
]
date = "2017-08-27"
categories = [
    "python",
]
+++

Over the weekend, I've been experimenting whether if its possible to set up screen recording on a linux server. This is partly just out of curiosity but also, a little a bit of frustration. Imagine if you were in a position where you aim to assist people in recording their training sessions over on Google Hangouts but in order to do so, you would need to be around and your computer needs to be "sacrificed" in order to do the recording.

Luckily, it seems that with a little experimentation work, it's possible to actually set up such a service on the side.

Let's start with what we would need to think about before we can get things started.

- Video/Audio recording software. A lot of people can easily suggest to look into OBS but for a automated system and on a linux, we might be better off with a command line utility. After researching a little on this, ffmpeg toolkit is mentioned pretty often in many of the linux/ubuntu forums.
- How to simulate going into Google Hangouts? We would need a browser simulation tool. Should we go with the headless tool such as PhantomJS or even Chrome browser headless mode?
- How the user would interact with the tool? Using a scheduling service via Google Calendar? Or allow the user the call upon the service via Slack?
- Possibility of hosting it on Docker? For this docker side of things, it is more of a personal desire to have it hosted on docker rather than on a normal instance; partly to increase portability of the tool but also to because of my familiarity with the tool

## Installing ffmpeg/avconv

So to start things of, we would think about the command toolkit. While looking around the linux forums, it turns out ffmpeg is not really available for debian-flavor of the linux systems. Instead, we would use avconv which is a separate fork of the ffmpeg command line utility.

There is so far little difference between ffmpeg and avconv command line tools. Any command copied over on forums that use ffmpeg is still usable on the avconv so that seems to be no issue from that angle.

## Installing a browser and simulating it

Previously I used PhantomJS to simulate the browser but with the big news that the maintainer for this stepping down, we would instead try Google Chrome headless mode instead.

News on Phantom JS maintainer stepping down
https://groups.google.com/forum/#!topic/phantomjs/9aI5d-LDuNE

The Google Chrome installation is slightly mode tedious as its installation is not part of the default apt-get list. We would need to grab that list and add it to our own on the server to even make it possible to install it.

The bash script that I would provide later would contain that.

## Possibility of Dockerizing it

Well, we can definitely dockerize the video portion of this screen recording mini project but it is difficult to record the audio portion of the screen recording in a docker container. Reason for this is that the tools that is the needed to run this (pulseaudio) seem to require some dbus mechanism which is not really exposed to the docker container but for all you know, I'm missing some configuration within the command line to switch it to an alternative mode.

In order to research further on this, I'm looking through some of the Dockerfiles that Jessie Frazelle has put up and that link is available here:

https://github.com/jessfraz/dockerfiles

However, even though we can only dockerize only the video portions of software, it can probably be used in other software ideas: e.g. Using it when running unit tests which provides video on how the software is interacting from the frontend.

## Putting it together

So, to put it all together, this is what we have:

- Installation of all the required components in a bash file. (You may need to install a text editor in order to add it to the server or you can choose to use git to do so)
  https://github.com/hairizuanbinnoorazman/video-recording-service/blob/master/install_gce.sh
- Instructions on how to run the service
  https://github.com/hairizuanbinnoorazman/video-recording-service/blob/master/USAGE.md

The instructions above are still very complicated as details are not ironed out yet but more details would come out soon. You can look into the project plan (https://github.com/hairizuanbinnoorazman/video-recording-service#whats-involved) and see if there are any other interesting things to add on to this.
