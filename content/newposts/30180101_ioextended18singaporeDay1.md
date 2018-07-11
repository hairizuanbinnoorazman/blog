+++
title = "Summaries from Google IO Extended 2018 Singapore - Day 1"
description = ""
tags = [
    "conference",
]
date = "3018-03-14"
categories = [
    "conference",
]
+++

This is not a in depth summary of the talks in Google IO Extended 2018. Rather, it is my notes from attending to the conference, which are heavier on links to find more about the topics. There are 2 days to the IO Extended 2018 event in Singapore. The list of talks below are from the first day.

List of talks

- [IO 2018 Highlights](#io-2018-highlights)
- [Profiling and Android Vitals](#profiling-and-android-vitals)
- [Web Presence](#web-presence)
- [Chatbots](#chatbots)
- [Android Jetpack](#android-jetpack)
- [Exoplayer Customization](#exoplayer-customization)
- [Kotlin and Java](#kotlin-and-java)

### IO 2018 Highlights

Some of the newer developments highlighted here:
- https://cloud.spring.io/spring-cloud-gcp/
- https://developers.google.com/web/tools/lighthouse/
- iOS was mentioned!! https://firebase.google.com/docs/test-lab/
- https://developers.google.com/actions/community/overview
- https://www.tensorflow.org/hub/
- https://js.tensorflow.org
- https://developers.google.com/machine…/crash-course/ml-intro

### Profiling and Android Vitals

A talk about managing performance in an Android Application. Due to the requirements of having more performant applications by users, there is a need to understand the performance of every aspect of the application. E.g. Network usage, battery consumption of certain sections of the application etc.

Links:
- https://developer.android.com/topic/performance/vitals/
- https://medium.com/@RenuYadav/android-vitals-an-initiative-for-good-health-12469a06fdb9

### Web Presence

Links for resources from this session:
- https://developers.google.com/search/mobile-sites/mobile-first-indexing

### Chatbots

There are two chatbot talks in this segment:

- IO Extended 2018 extended chatbot
- Eddy the eagle chatbot

The main technology powering the chatbots is this: **DialogFlow**

When a chatbot receives a text from a user, it needs to sent it to a "server" for processing. One of the cheaper ways to handle these are via the cloud functions (serverless option). After doing the initial processing, the text can be sent over to dialogflow which would then retrieve and categorize what intent does that mean. The intent values are returned to the serverless function which would then respond to the user accordingly.

IO Extended 2018 chatbot mainly revolves around only dialogflow and firebase cloud functions. However, the Eddy the eagle chatbot shows how chatbot can truly be useful to everyday life. The Eddy the eagle chatbot aim is to be able to allow students at a school to quickly look up lists of homework or lesson schedules rather than going through a bunch of links just to retrieve the information they need.

Links to additional resources:
- https://dialogflow.com/
- https://firebase.google.com/docs/functions/
- https://www.slideshare.net/SohitGatiganti/eddy-the-eagle-the-student-chatbot-104725786
- https://github.com/sohit39/SAS_Chatbot
- https://github.com/yogendra/io-ext-sg-2018

### Android Jetpack

Links for this session:
- https://android.jlelse.eu/introduction-to-android-architecture-components-with-kotlin-room-livedata-1839c17597e
- https://github.com/googlesamples/android-sunflower
- https://github.com/googlesamples/android-UniversalMusicPlayer
- https://github.com/googlesamples/android-architecture-components
- https://codelabs.developers.google.com/?cat=Android
- https://developer.android.com/topic/libraries/architecture/

### Exoplayer Customization

On android, there is a media player object that can be used to play videos. However, it is quite inflexible, and it is difficult to use when it comes to managing and handling video playing at scale.

Links to some of the resources out there
- https://github.com/google/ExoPlayer
- https://en.wikipedia.org/wiki/Dynamic_Adaptive_Streaming_over_HTTP

### Kotlin and Java

Getting kotlin and java to play nice while developing an android application

Additonal References:

- https://developer.android.com/kotlin/ktx
- https://github.com/android/android-ktx