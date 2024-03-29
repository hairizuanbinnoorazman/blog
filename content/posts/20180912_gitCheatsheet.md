+++
title = "Git Cheatsheet"
description = "Using the various git commands such as git init, git checkout, git rebase etc"
tags = [
    "git",
]
date = "2018-09-12"
categories = [
    "git",
]
+++

Git is one of the most important tools in a software developer arsenal. It is one of the main tool developers use in order to handle and control their code versioning. Mastering it would definitely make one's life way easier and better; failing to do so will bring one into a world of pain. This post doesn't intend to explain vital concepts such as git branches and forks and remotes in great detail so it would ideal if one pick those conecepts before proceeding on with the commands.

## Some basic git concepts

- Branches
  - https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell
- Forks
  - https://help.github.com/articles/fork-a-repo/
- Remote
  - https://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes

## git - The beginning

This is assuming that this is the first time you are using git for your projects and you need a quick list of commands to get something done. In that case, the following list of commands would take you through the following steps:

- Cloning a repository to your local computer
- Working on your own branch (lightweight) copy of your local computer. This will help prevent your code from messing up master branch.
- Add your changes, commit and push to remote
- Update your local clone by fetching, doing diff and comparing

```bash
# Clone a repository
git clone {{ remote url }}
git clone https://github.com/user/repo.git # e.g.

# Creating a new branch
git checkout -b new_branch

# After making some changes
git add --all
git commit -m "A new temporary feature has been added"
git push -u origin new_branch

# After making even more changes
git add --all
git commit -m "Another new temporary feature has been added"
git push

# After this, do a PR to master branch

# If more changes has been added to master and you need to build off the latest master
git fetch origin master # Fetches it to origin/master branch locally
git diff master origin/master # Checks that the diff is fine, no issues caused
git pull origin master # Does a fetch and merge from origin/master into master

# Cycle repeat
```

A few things to note; initially, try to not get into the habit of the following:

- Don't push to master (This should be code that everyone/code owners agree to add to the codebase. In order to make the process of code acceptance to master more obvious, pull requests can be done against it)
-

## Necessary rebasing efforts

It is often mentioned that rebasing is bad but it is more right to say that rebasing is bad if it affects people who happen to be working on the code. However, in the case of bigger code bases, you don't necessary want to litter your commits with redundant commits. There could be commits that are changes and its reverted changes. Those kind of commits can be "dropped" out. This can be done via the `git rebase` command.

```bash
# If you are on temp branch
git rebase master
# It compares master to temp branch, rewinds back to the commits that master has, then replays additional commits to the tip of master

# If you need to drop, squash, alter commit messages:
git rebase -i HEAD~10  # Or choose another number
# This allows you to do interactive manipulation of git code history.
# Before doing it and merging it to master and all, try it on some sample branches.
# Make sure that the git commit ids are correct and as expected
```

## Useful git commands

List of useful git commands. This is not a full exhaustive list of git commands available. If you're seeking that, you might want to refer to git man pages.

```bash
# Initialize a git repository
# One can create a git repository anymore. You don't necessary need a remote git repository for this
git init

# Cloning a repository from remote url
# Default branch is usually master
# Remote is usually called origin
git clone {{ remote url }}
git clone https://github.com/user/repo.git

# Adding changes
git add --all # Try not to use this
git diff {{ file name }} # Check what changes has been done on the file so far
git add {{ file name }}

# Having multiple remotes
# In the case where you want to move repos between groups or mirroring repos between multiple repos
# It is also another way to
git remote -v # This is to view list of remotes available
git remote add {{ new remote ref }} {{ new remote url }}
git remote add tempMirror https://github.com/user1/repo.git

# View list of logs
git log
git log -n 5

# View commit information
git show {{ commit id }}

# Checking out to other branches
git checkout {{ branch_name }}
git checkout {{ commit id }}
git checkout tags/{{ tag name }}

# Deleting branches
git branch -D {{ branch name }}

# Viewing branches
git branch

# Grabbing branches from remote
git fetch origin {{ branch name }}

# For safer development, create a new branch and then do pull request to the master fork/branch
# Creates a new branch of from the current branch
# You can then push it to remote accordingly
git checkout -b {{ new branch name}}
git push -u origin {{ new branch name }}
# After doing some changes, you can then do the following as you have already added the remote accordingly
git add --all
git commmit -m "Commit message"
git push

# If you don't want a commit in a git repostory, you can revert the commit
# This would create a new commit that does the reverse of a commit selected
git revert {{ commit id }}

# To view who made the changes to a file etc, you can either dig through each commit one at a time
# OR, you can just use the following command
git blame {{ file name }}

## Bringing over changes from another branch to current branch
git cherry-pick {{ commit id }}

## You've created a PR and you need to update the PR based on other people's comments
## This is assuming that other people are reviewing the PR as a whole;
## They do not wish to see the changes made as compared to the last time you review it
## Instead of adding a bunch of commits and squashing them, you can just "amend" said commit on PR
## This allows you to amend the commit as well as the commit message
git commit --amend
```

## Git submodules

These are pretty rare, it would occur for larger code bases; code bases that orchestrate and make use of many different components which may not be heavily depended on by the project.

```bash
# Initialize submodules
git submodule init

# Update the submodules
git submodule update

# Combine the init and update together recursively
# (Go down through the folders and initialize and update the submodules along the way)
git submodule update --init --recursive
```

Updating the submodules only mean changed the git commit reference for the main code repo. One can just do normal git interactions in each of the child repos but once you got up to the main repo, you will update the commit hashes for each of the child repos that has been altered.
