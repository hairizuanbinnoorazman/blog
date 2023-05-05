+++
title = "Serving Videos with Golang via HLS"
description = "Serving Videos with Golang via HLS, assisted with ffmpeg tool"
tags = [
    "golang",
]
date = "2023-04-05"
categories = [
    "golang",
]
+++

I was watching a bunch of tiktok and youtube videos  recently and kind of started to wonder how such companies serve videos to their consumers. That is where I started to going down the rabbit hole of how videos are served and how to try to ensure the possibility that videos can be played without requiring to download the entire video.

Apparently, one of the technologies that was mentioned for streaming videos from server to a consumer device was HLS. HLS stands for HTTP Live Streaming. Although we're not exactly doing "live streaming" if we're just attempting to serve video - however, if we were to think twice about it, we're kind of "streaming" the contents of the video to the user. We would want the user to be able to consume the content even before the entire video is loaded. 

To do this HLS thing, we can rely on the usual video manipulation tool - ffmpeg. In order to get the HLS form of the video, we would need to re-encode the video to the HLS format; this blog post will mention an example command that can be used for this. The HLS format consists of a single file that would provide a list of all files that would point to the various video segments of the entire video. The reason for breaking this up the file into smaller video segments is to allow the consumer device to download a smaller piece of content and start playing without requiring to download the entire video. Downloading large files over the internet is usually not the best thing for a app/websites - smaller files usually work way better; if there is any broken connections, it would still be possible to restart downloads of small video chunks. At the same time, with the HLS format, we would be able to download maybe a couple of video chunks and immediately start playing the video.

This blog post won't cover on how one can obtain ffmpeg on their workstation. But if you're on a Mac, you can probably get it by utilizing `brew`.

The next step would be utilize the ffmpeg tool to convert the target video which we wish to serve to a "HLS" format. The HLS format of video consist of a `m3u8` file which serves to be some sort of "manifest" file. This is the "single file" that point to the various video segments. This is the command that would help to do so:

```bash
ffmpeg -i sample.mkv -c:a copy -f hls -hls_playlist_type vod output.m3u8
```

Let's cover the effects of some of the flags being used above:  
- `-i` refers to the input file. The input above is `sample.mkv`
- `-c:a` refers to the step to copy the audio over to the encoded file
- `-f` refers to the format 
- `hls_playlist_type` is one of the options specifically for encoding videos for the hls format. This one is partically needed in order to ensure all video segments are added to the `m3u8` file. The default is the last 5 entries for the video (so it'll only play the end of the videos. Reference: https://stackoverflow.com/questions/65069045/only-last-four-entries-of-ts-files-found-in-out-m3u8-file-when-i-am-using-ffmpe)

Once we have done with running the command - we would generate the files. However, how shall we test that the video has been encoded to the hls format. We can do so by utilizing some common video player (in my case, I usually use VLC media player) and point it to some server that would be a file server to serve the `m3u8` file as well as the `ts` video segment files.

The golang code to do so is available here:

```golang
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	http.Handle("/", http.FileServer(http.Dir(".")))
	fmt.Printf("Starting server on %v\n", 8080)
	log.Printf("Serving %s on HTTP port: %v\n", ".", 8080)

	// serve and log errors
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", 8080), nil))
}
```

For some guides on how to play `m3u8` based videos, refer to the following reference: https://www.5kplayer.com/vlc/m3u8-vlc.htm

The next step after this is to try to render the video on a html page served by the Golang server. Unfortunately, a naive approach of using the `<video>` html5 tag doesn't work in Chrome browsers. Surprisingly, HLS is not natively supported in Chrome browsers - there are formats that are properly supported but a deeper dive is needed to find out how those work and how we can utilize ffmpeg to generate said video streams. We have to use javascript based solutions to provide said functionality on Chrome.

One might argue - why not just develop for Chrome? Unfortunately, the Chrome browser is still one of the more popular browsers in common use. At the same, other browsers such as the edge browser are based of the Chromium project - it is pretty safe to assume that if chrome doesn't support HLS formats natively, then, other chromium based browsers wouldn't provide such support as well.

For the following quick example, I decided to go with `video.js` as it is one of the libraries that provide a "working" example (also, quite a number of reputable video based companies are listed on its website.). With that, we can then include serving of a html page with `video.js` javascript functionality.

This would be the Golang server code:

```golang
package main

import (
	"fmt"
	"html/template"
	"log"
	"net/http"
)

type VideoServe struct {
}

func (h VideoServe) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	t, _ := template.ParseFiles("aaa.html")
	t.Execute(w, nil)
}

func main() {
	http.Handle("/yoyo", VideoServe{})
	http.Handle("/", http.FileServer(http.Dir(".")))
	fmt.Printf("Starting server on %v\n", 8080)
	log.Printf("Serving %s on HTTP port: %v\n", ".", 8080)

	// serve and log errors
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", 8080), nil))
}

```

For the html page named `aaa.html` that would be served by the Golang server coded above.

```html
<html>
  <head>
    <title>Hls.js demo - basic usage</title>
    <script src="//cdn.jsdelivr.net/npm/hls.js@latest"></script>
  </head>

  <body>

    <center>
      <h1>Hls.js demo - basic usage</h1>
      <video height="600" id="video" controls></video>
    </center>

    <script>
      var video = document.getElementById('video');
      if (Hls.isSupported()) {
        var hls = new Hls({
          debug: true,
        });
        // hls.loadSource('https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8');
        hls.loadSource('http://localhost:8080/output.m3u8');
        hls.attachMedia(video);
        hls.on(Hls.Events.MEDIA_ATTACHED, function () {
          video.muted = true;
          video.play();
        });
      }
      // hls.js is not supported on platforms that do not have Media Source Extensions (MSE) enabled.
      // When the browser has built-in HLS support (check using `canPlayType`), we can provide an HLS manifest (i.e. .m3u8 URL) directly to the video element through the `src` property.
      // This is using the built-in support of the plain video element, without using hls.js.
      else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        // video.src = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
        video.src = 'http://localhost:8080/output.m3u8';
        video.addEventListener('canplay', function () {
          video.play();
        });
      }
    </script>
  </body>
</html>
```

With that, we should be able to stream some sort of video from our Golang server to our browser. However, we would probably need to research further into it; there are many other things that we would need to take note and attempt to fix for: one of which would be to do the encoding ffmpeg job on demand - the example above requires us to encode an other video and have the transcoded videos available before the user accesses it. That would require unnecessary space on our part (especially if storage space is tight in the first place)

I'll probably look to cover some of these in another blog post.

## References
- https://hlsjs.video-dev.org/demo/
- https://developers.cloudflare.com/stream/examples/hls-js/
- http://underpop.online.fr/f/ffmpeg/help/options-51.htm.gz
- https://ottverse.com/hls-packaging-using-ffmpeg-live-vod/
- https://ffmpeg.org/ffmpeg-formats.html#Options-10
- https://ffmpeg.org/ffmpeg-filters.html#subtitles
- https://superuser.com/questions/996149/how-do-i-map-vf-subtitles-with-ffmpeg
- https://medium.com/bootdotdev/create-a-golang-video-streaming-server-using-hls-a-tutorial-f8c7d4545a0f
- https://www.baeldung.com/linux/subtitles-ffmpeg
- https://trac.ffmpeg.org/wiki/HowToBurnSubtitlesIntoVideo
- https://ffmpeg.org/ffmpeg-formats.html#hls-2
- https://stackoverflow.com/questions/19782389/playing-m3u8-files-with-html-video-tag