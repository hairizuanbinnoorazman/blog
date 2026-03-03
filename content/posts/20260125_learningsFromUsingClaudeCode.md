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

E.g. Let's say if we have a huge dataset to process. We shouldn't dump the entire dataset into the model - that'll just be a waste of money in terms of input and output. The answer we're getting also doesn't have a good chance of being correct as well - models are not known to do math very well (remember the count the number of r in strawberry). Instead, what we can do is to have the model write script that can do such tasks - we'll get an intermediate output which we can inspect - and if that intermediate output is good, we can simply use it to get the result we want. - a concrete example would be to have the model to generate a sql script which we can then use to query the dataset.

Another E.g. Let's say if we have a large log to collect. The log is accessible via some particular endpoint which could have been provided in the CLAUDE.md. If we let the model to collect the log on its own - it might proceed to curl and then pull the log and the entire log would easily end up in model context. If we alter the angle to have the model call a particular function that is standardized to retrieve the log that could be written as a file - that could be a better approach? And with that approach - there is no need for the model to try guessing how to receive the log

## Send image instead of describing the problem

Inspiration from this: https://www.youtube.com/watch?v=M8kZLuukZgk  

Apparently, Claude understands images quite well - but it can't generate images unfortunately. We can do things like taking screenshots or drawings and then pass it to the model. (Reference the feedback loop sections with playwright - some of the operations it might do is to take screenshot to confirm that the task is done or to understand context of the problem)

## Running multiple claude code runs at one go

This one is also an inspiration from this video: https://www.youtube.com/watch?v=B-UXpneKw6M&pp=ygUUYm9yaXMgY2hlcm55IGFpIGxhYnPYBvwC  

We can setup a 4 screen iterm on mac os to run 4 different process run at one go  

This allows faster code or output generation but it show bottlenecks in different place - which in this case - that would be at the pull request 

## Keep Claude Code coding harness updated consistently

Claude code improves at high speed over the past few weeks. Some of the latest and greatest feature simply get introduce very recently (beginning of this year). Some interesting examples of such concepts would be:

- Skills (A differentiated approach to mcp tooling - progressive disclosure)
- Task management
- Swarms

I'm still struggling to keep up with all the things that is happening in the market

## Spec-driven development vs one shot vs breaking up tasks for agents

There are numerous ways to work with all the AI tooling.

- Spec driven development - essentially, do a Product Management task to develop in-depth requirements document to cover the various features and edge cases of each feature. The entire document crafted can then be passed to AI tooling and potentially, an entire swarm of AI agents can cooperate to work on it.
- One shot prompt - the ones that sometimes big companies market about constantnly - e.g. Anthropic on creating C compiler or Cloudflare creating a JS runtime based off Next.js
- Breaking up tasks for agents and passing one small task to agent one at a time

I lean more on the last option of the way for developing tools/products - the first option involves too much work to decide on the various aspects of the product - which could potentially go wrong as implementation starts (e.g library not available to support the feature?) - not 100% coverage while implementation is done on spec - too big of a massive change to review for a human. Second option feels like you're gambling - you're simply relying on the AI to plan and research - it does get better but highly likely, there will be various assumption that one does not agree on during implementation.
