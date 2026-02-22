+++
title = "Learnings from building agents"
description = "Learnings from building agents"
tags = [
    "automation",
]
date = "2026-02-01"
categories = [
    "automation",
]
+++

I've tried to build a bunch of AI agents at work for a variety of purpose and with that, learnt a couple of interesting properties out of it:

## Should it even be an agent?

Agents are definitely an exciting piece of tech and various media outlets and blogs make it seem like its the silver bullet to solve almost everything. However, as with all things in tech - this as with all the supposedly proclaimed "silver bullets" - building agents is not the silver bullet that people think it is. At the end of the day, whether one should implement it as a agent depends on the problem set.

The most important factor to take note is this: Do we need an absolute deterministic result at the end of the process. If yes, then it's best to use plain old programming languages and write a script for that. One can use AI to generate said script but with a script - we will have a deterministtic result (i'm ignore side effect that could happen when running the scripts - e.g. timing issues etc - that'll result in flaky results but its still somewhat deterministic at the end of day)

If the problem is more probalistic in nature - e.g. debugging a issue where there could be multiple issues and solutions, having and building an agent could help with this. The agent could be tasked to dig through the various pieces of information and with the right set of instructions, it could be used to summarize the results in a useful manner for an engineer to review. It serves well as the first pass for debugging an issue.

## Where will this thing run? Who will run it?

If the agent thing will be run by a human, maybe can consider to just run use just use the coding harness such as Open Code or Claude Code. The coding agents is able do a whole variety of activies such as calling endpoints or running scripts (assuming you're giving it permission). 

There is a benefit to make it accessible from Claude Code - we can combine multi workflows into one and this combination of instructions makes the tool interesting and powerful.