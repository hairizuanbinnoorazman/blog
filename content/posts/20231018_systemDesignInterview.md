+++
title = "System Design Notes"
description = "Notes taken down for system design - part for system design interviews"
tags = [
    "microservices",
]
date = "2023-10-18"
categories = [
    "microservices",
]
+++

## General framework for system design interviews

From the following website: https://www.youtube.com/watch?v=i7twT3x5yv8  

- Specify Requirements
- Design High Level Functional Components
- Deep dive to specific "interesting" pieces of the components
- Wrap up

- Usual points:
  - Request for estimated users for the application to determine scale of the application
    - To help find out ratio of reader to writers.
  - Any "feed" need to ask about "freshness" of data. How frequently does it need to be updated? (But does this matter here?)
  - Technical requirements:
    - Availability of system
    - Ok for data to be eventually consistent or is consistent data a requirement here?
    - Latency of content to be distributed
    - Fault tolerance (able to withstand failures)
  - Use Queue for potentially slow process or processes that may suddenly spike in requirements

## Design an "Instagram" app

- Business requirements
  - User has a home screen which provides a feed of photos/videos of other people. Assumed that priority for the feed would be people "close" to the user
  - User submits photos or videos and adds metadata to such assets when posting. E.g. tags
  - User is able to vote for which photo they like best which would help identify which content is "good" content
  - User is able to "follow" other fellow users
  - Is this a global app? Or just simply a regional app?
  - It is assumed that the model of the this "instagram" would have the same business model - serve Ads to make money
- Technical requirements
  - How many users are expected to use the app on daily basis?
  - When accessing content, can it be assumed that we would want to reduce content sizes for users - in order to improve the responsiveness of the app and reduce amount of bandwidth needed to show the content?
- High level components
  - User service. Manages user information as well as the closeness of users to other users. Track the followers information.
  - Content Submission service. Handles content being submitted by user. Involves processing the content for storage as well as future service as needed.
  - Feed generation service. Involves in generating the feed that each user would be consuming. Some of the information that it requires to generate the feed would be the closeness of the user to other relevant user, recency of the post, the amount of likes of the post etc. Feed generation service would probably use an algorithm/ML to train on all these data to determine which feed would be best served to provide the greatest revenue/engagement.
  - Metrics absorption service. Collect business metrics on how posts are engaged by users. Information such as:
    - App usage time
    - Number of posts user went through
    - Time spent on each post etc
  - Ads service. Involves with providing ads purchased by individuals/companies. Consumed within the feed.

## Design a live-streaming application

TODO: Read up further on this

- Requirements
  - Take video stream from user's web camera + microphone from browser/app and encode the data that is for live streaming
  - User is able to select the stream that is to be watched
  - User is able to download the right bitsized video for best viewing experience (e.g. handphone has smallest screen and doesn't need to watch it in "True HD" fashion.)
- Technical Requirements
  - Low latency between time when video inputs is captured to when viewers are watching the stream
  - Video stream is available globally to everyone at the same time
- High level components
  - Client application (browser) that is able to access the camera + microphone to record information. It will then encode the data as RTMP/RTMPS to send the data over to the server.
  - Transcoding component. Component that will take RTMP input and then run appropiate manipulations on it to downsize the data accordign to different bitrates. Apparently, ffmpeg seems to be able to immediately do such computations in a single jump.
  - Client application (viewer) to view content via HLS format.

## Design a key value store

TODO: Research on the following:
- Storage Engine: SStable, Bloom Filters

- Requirements
  - To store set of keys mapped to its values in a persistent fashion. Data is not lost on shut down.
  - Able to take in a moderate number of connections with no issues when pushing/getting data
  - Data stored on disk cannot be in clear text format
  - Able to operate as a cluster
- Technical requirements
  - Low latency when retrieving and saving data in the datastore
- High level components:
  - Cluster components:
    - Leader election. Needed when clusters are formed. Certain operations where only 1 operation can succeed requires leader to be available and to decide what to do next.
    - Data moving subcomponent. Move data between nodes in the cluster
    - Partitioning of data component. In this case, maybe consistent hashing is the best solution to prevent so much data from moving around.
    - Memberlist. To see who's part of it and who's not. If no longer healthy, need to start moving data around.
  - Query Engine:
    - Allow capability to handle further complex requests from clients
  - Storage Engine:
    - Consists of 3 things. Commit log, Memory Cache and Write to Disk

## Design Tiktok

- Requirements
  - User is able to submit in short clips of videos
  - User is able to edit the short clips of videos
  - User is able to follow other users to see what content they post etc
  - User able to interact with the comment by liking or commenting on it
  - User will be on a feed that will provide a list of short form videos that they will view
  - User will be served ads in order to make money for the application
  - There will be metrics that would collect business metrics based on how users interact with the application
- Technical requirements
  - Short videos served would need to be served at low latency with low bandwidth usage
  - Amount of time between upload and content availability should be low?
- High level components
  - User service (deal with users following other users etc)
  - Ads service
  - Video submission service
  - Video viewing service
  - Video editing service
  - Metrics service
  - Feed generation service