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

Here are some of the learnings for using Claude Code

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

## Running multiple claude code runs at one go

This is an inspiration from this video: https://www.youtube.com/watch?v=B-UXpneKw6M&pp=ygUUYm9yaXMgY2hlcm55IGFpIGxhYnPYBvwC  

We can setup a 4 screen iterm on mac os to run 4 different process run at one go  

This allows faster code or output generation but it show bottlenecks in different place - which in this case - that would be at the pull request stage
