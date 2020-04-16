+++
title = "Recording demos with free tooling"
description = "Recording demos free tooling"
tags = [
    "personal",
]
date = "2020-04-15"
categories = [
    "personal",
]
+++

There are various tooling out there that helps deal with screen recording etc. However, many of these tools/sites would somehow provide the recordings at a price. Maybe you can only record a certain number of hours of video per month? And the videos are non-downloadable (unless you pay for it) and it would expire after a set period.

Luckily there are awesome tools out there that would provide such functionality

For recording of screens while doing demos, one can utilize OBS (Open Broadcaster Software) - https://obsproject.com/. Although the purpose in this case is pretty simple where we just want to record our screen while doing technical demos, however, the OBS tool can go way beyond that. You can easily take multiple streams of videos and audio and mush it into a single video or even stream that video straight into youtube etc.

However, even with such a tool, it doesn't provide capability to output gifs (maybe we would want to just put an image on the site rather than upload a whole video and manage its lifecycle and deal with issues that arise from hosting videos.)

One can utilize ffmpeg to do so.

Out of convenience, one can utilize ffmpeg available in a docker image to do this work: see the command below

```bash
# Windows environment
docker run --rm -v c:/Users/USER/Videos:/temp jrottenberg/ffmpeg -i file:/temp/lol.mkv -r 15 file:/temp/lol.gif
```
