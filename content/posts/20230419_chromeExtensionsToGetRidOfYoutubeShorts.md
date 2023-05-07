+++
title = "Chrome Extension to get rid of Youtube Shorts"
description = "Chrome Extension to get rid of Youtube Shorts during youtube video search"
tags = [
    "personal",
]
date = "2023-04-19"
categories = [
    "personal",
]
+++

I hate Youtube Shorts with a passion. Youtube shorts are a plague in my ways and it seems to be that it's main purpose is to drag me down to waste hours of my time watching stupid short clips that are usually only mildly amusing. And at the end of it all, I don't feel satisfied or feel entertained after wasting hours on it. (Maybe it's just my age catching up to me and myself going with the usual trend of old people hating the new hype thing)

However, regardless of what one thinks of it, it would be nice to somehow get rid of said videos from even being viewed on my browser (technically, I use youtube the most on my own computer, so it makes sense to start from there). I never really had the drive to this until a recent change on the youtube website happened: you can no longer tell the website that of removing the youtube shorts shelve for a month. It is now a permanent feature and you're forced to view it no matter how you feel about it. I guess that's the final straw for me to try to find a way to build something for this (it's a learning opportunity as well...)

I guess to start learning how to build a chrome extension, it would be best to start from some of quickstart example. Luckily, the chrome extension page does have something, so we can simply copy and paste some code to get something working. https://developer.chrome.com/docs/extensions/mv3/getstarted/development-basics/

After getting an extension into the browser, the next step is to see how to run some form of javascript to do the required magic of removing the trashy content from the webpage. The following page provides a good guide to get started on where to write the javascript that would do the page manipulation: https://developer.chrome.com/docs/extensions/mv3/getstarted/tut-reading-time/

After some trial and error, I finally got some hacky javascript into the chrome extension and got it working. The following piece of javascript is able to do the following: Remove youtube shorts shelves as well as remove any video content that points to a youtube short.

```javascript
function listener()
{
    // Remove all youtube shorts shelves
    aa = document.querySelectorAll('ytd-reel-shelf-renderer');
    aa.forEach((a) => {a.remove()});
    console.info("deleted youtube shorts shelves");

    // Remove all youtube shorts video
    bb = document.querySelectorAll('#video-title');
    bb.forEach(item => {
        if (item.getAttribute('href') == null) { return; }
        if (item.href.includes('https://www.youtube.com/shorts')) {
            item.closest('ytd-video-renderer').remove();
        } 
        console.info('deleted youtube shorts video');
    });
}

var timeout = null;
document.addEventListener("DOMSubtreeModified", function() {
    if(timeout) {
        clearTimeout(timeout);
    }
    timeout = setTimeout(listener, 500);
}, false);
```

There are a few things about the javascript code above; one is that we need to add the code to add event listener etc because the youtube website doesn't load all of the content at one go. It actually pulls more html/js content as you scroll down through the webpage which it results in further rendering. A naive attempt to simply remove "offensive" html elements once page is loaded is insufficient. We would need to keep checking node content every once in a while and clean out in some sort of loop.

Another important thing about this Javascript code is its extremely inefficient - and its impact shows. The moment a youtube page is scrolled through, CPU usage climbs rather quickly - so the implementation here is probably not for the best. It's best to revisit it once more in the future if the performance issues continue to plague me for it. 

I will probably continue to add more features to it such as remove an entire class of content (e.g. reaction videos) as well as videos that are under 10s. But that'll be for another post.