+++
title = "Learnings from using Claude Code"
description = "Learnings from using Claude Code"
tags = [
    "automation",
]
date = "2026-01-25"
categories = [
    "automation",
]
+++

Here are some of the learnings for using Claude Code. This will be a running document of learnings as we go along for the ride of using this tool  

Last update: 26 January 2026  

## Utilizing Claude Plugins/Skills/Commands

There are common prompts being used over and over again. One common prompt that I commonly use on a day to day basis - e.g. "Commit the changes that has been done so far with summary of changes as the commit message and push it remote". This prompt is quite long and becomes a hassle to type over and over again. However, once we create embed such things as a slash command - it becomes trivial to simply recall this prompt. And a even nicer fact is that now, since a slash command is usually a markdown file - we can provide even more details and context of how the slash command would operate (although larger prompts would naturally take up room in the context window - too big is also too bad)

An interesting thing that was mentioned was that one can actually utilize the slash commands midway in a prompt as well. An example would be:

- `/commit2remote` - a slash command to commit changes with a summary of changes as commit message and push to remote
- `/run-linter` - a slash command to run variosu linter checks

So an example prompt could be: "Run /run-linter and then if there are no issues, /commit2remote" - but in general, i don't exactly do this

Nowadays, my main 2 slash commands:

- `/issue2code` - Takes github issue and description. Read it and go into planning mode to try to implement it as code
- `/commit-pr` - Push the code with summary of changes as commit message and push to remote and then create MR from it

## Updating the CLAUDE.md consistently

CLAUDE.md is the main file that we would use for understanding a particular codebase. As the codebase evolves, naturally, we should update the CLAUDE.md so that the model being used would be able to understand the codebase correctly without us consistently telling it that it's doing something wrong etc. It can immediately start with correct understanding and standards.

An example could be a situation where a python codebase started out without any typing information as parameters in functions. However, let's say we have done tasks to introduce typing across the codebase - if the CLAUDE.md doesn't have this explicitly - then it could have a chance to generate functions that might not fit that coding standards. If this was done more explicitly - it should know and will be conform in a better way

## Try Planning mode

This is an inspiration from this video:: https://www.youtube.com/watch?v=B-UXpneKw6M&pp=ygUUYm9yaXMgY2hlcm55IGFpIGxhYnPYBvwC  

Use planning mode when trying an implementation. Reason for why planning produces pretty good output is due to the exploratory steps being run before hand. The explore steps help to build up the context which can then be used to draft a deeper through plan. A nice part is that at the end of planning mode, there is an option to clear context and ask the model to one shot the implementation based on the models

## Establish feedback loops

Claude model can easily write up the code at one go but sometimes - how would we know that the output works? This is where we can supercharge the process and remove the manual parts (especially QA parts)

The easiest straight forward path is to have integration tests - and also mention it in CLAUDE.md. Once the model knows this - it will automatically know to run this and ensure that the integration tests passed. First it'll implement the code, then it'll run the integration tests. Once all tests passed, then the model will declare that the task is done.

Other examples of feedback loops:

- UI changes by either have playwrite UI tests. Or just give the model playwright mcp server
- Creation of Jenkins jobs and have the model run the newly created jenkins job until it succeeds

## Introducing abstractions

AI models is not cheap. If there is a somewhat solved problem - we can introduce abstractions so that we can reduce the amount of tokens being used just to do fetching of such data.

E.g. Let's say if we have a large log to collect. The log is accessible via some particular endpoint which could have been provided in the CLAUDE.md. If we let the model to collect the log on its own - it might proceed to curl and then pull the log and the entire log would easily end up in model context. If we alter the angle to have the model call a particular function that is standardized to retrieve the log that could be written as a file - that could be a better approach? And with that approach - there is no need for the model to try guessing how to receive the log

## Running multiple claude code runs at one go

This one is also an inspiration from this video: https://www.youtube.com/watch?v=B-UXpneKw6M&pp=ygUUYm9yaXMgY2hlcm55IGFpIGxhYnPYBvwC  

We can setup a 4 screen iterm on mac os to run 4 different process run at one go  

This allows faster code or output generation but it show bottlenecks in different place - which in this case - that would be at the pull request stage
