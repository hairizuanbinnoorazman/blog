+++
title = "Solving the File Sync Bottleneck in tests: How Torrenting Could Be the Answer - Part 1"
description = "Solving the File Sync Bottleneck in test: How Torrenting Could Be the Answer - Part 1"
tags = [
    "torrent",
    "cicd",
    "devops",
]
date = "2025-07-01"
categories = [
    "torrent",
    "cicd",
    "devops",
]
+++

At my job, one recurring technical challenge has been syncing massive files—often ranging from 10GB to 20GB—across multiple servers. We're essentially copying over large iso files around to various servers. The current process still somewhat works but it is bandwidth-intensive, and increasingly difficult to manage as our the number of servers we need to sync this large file grows. Traditional solutions like rsync or SCP work, but they don't scale well when the same file needs to be pushed to dozens of machines.

This got me thinking: what if we treated file distribution more like content distribution? More specifically, what if we used torrents—a technology built precisely for efficiently sharing large files across many nodes? In this post, I’ll walk through the problem we face, why torrents are an intriguing alternative, and what it might take to implement such a solution.

## Why torrent and not rsync or scp etc

There were a couple of requirements that we need in order to setup tests

- Able to sync large files
- Able to sync said files across multiple servers (easily could be more than a dozen) in a relatively short time
- Able to ensure that the large files are synced correctly. Ideally, it would be great if there was a mechanism that is able to check that the files are synced correctly. Any mis-sync would result in failures in the tests that are to be executed.
- Ensure that it does not overwhem the main server where the download originates from.

We had a first naive implementation where we assume that bandwidth was "unlimited" for the server. This was done by having all the servers connect to the main origin server that produced the large file and transfer the file via scp/rsync. It literally melted at the server and result it to max out on its bandwidth. An initial attempt resulted in it taking 40 minutes or more - probably more time was spent by server to round robin across all the connections. No wonder it took such a long time.

The next approach naturally focused on reducing the need to transfer all this data at one time - what if all the servers had a queue? We could simply have the servers queue up one at a time and scp the file from the main origin server to the destination server. This definitely worked and it took roughly 2-2.5 minutes each time. This would mean that if there was 10 servers, it could take 20-25 minutes to transfer the file over to all the servers.

However, we can definitely go faster (although not sure if there is a need to at the moment). What if we made it such that all the destination servers that need to download the file could all download parts of the file from each other? That's technically the whole point of torrenting - its the capability to share files peer to peer. It has that capability to copy parts of files over from servers that already has those said portions.

## Planning out the project

I wasn't too familiar with torrenting technology so luckily, I saw a reference to code crafeters about building your own torrenting client. What we want here is a torrent that is not connected to the internet. The torrent tracker has to be internal - the torrent clients also cannot to the internet as well. Everything has to be internal.

This is the refence link: https://app.codecrafters.io/courses/bittorrent/overview

Seems like the overall steps for this is as follows:

- Understanding the torrent file
  - Apparently, this involves understanding the encoding method that torrent files used
- Understand how to get peerlist + initiate download of a piece of the file via torrent
  - We will skip writing a blog post on this portion. Essentially, we just need to follow and try out the content on code crafters
- Build out 2 bittorrent clients that are able to communicate to each other. We can assume that 1 of the torrent client already has the file - the other torrent would simply need to run through all blocks to copy the file over.
- Build out a torrent tracker
  - Have the bittorent client connect and report/get stats from it. Peer information should be able to be retrieved from it
- Build out a torrent manager of sorts. This tool doesn't need to track torrents per say but users should of this tool should be able to go to it, upload a file and receive a torrent file that can then be passed the built torrent clients from before
- Try the tool for real for multiple clients connecting to one main client that holds the origin file. At this stage we need to ensure and check that load is truly shared between all clients. https://www.bittorrent.org/bittorrentecon.pdf
  - How to ensure that one client is not overloaded - how to penalize or reward clients so that the workload can be spread around

This is a pretty hefty list of items to go through - so, we definitely cannot cover in a single post. However, I will link all related post to this post to make this as a the main post that I can reference to when discussing about technical issues about torrents

## Links

TODO - No links yet available. Will be added in the future
