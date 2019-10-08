+++
title = "Cookiecutter template for Google Cloud Run"
description = "Cookiecutter template for Google Cloud Run"
tags = [
    "google-cloud",
]
date = "2019-10-05"
categories = [
    "google-cloud",
]
+++

While working on a couple of projects that would be deployed on Google Cloud Run, I realized that a couple of them tend to have some sort of similar structure. Due to the number of repositories I would typically handle on a personal basis as well as the amount of context switch I would need to move between projects; it would ideal that all of such projects are automated as much as possible.

This is a small list of features that would great to be templatized across projects:

- Cloud Build templates
  - Include the handling of secrets via Google KMS if necessary.
  - Handle cases between http based vs msg based Cloud Run deployments (they have slight differences which can easily trip you while you are rushing out a project)
  - Handle little issues when dealing with Cloud Build; Previously, I found out that Cloud Build would generate a `.gcloudignore` file from a `.gitignore` if it doesn't exist. Let's say you were to deploy it to Google Cloud Functions and you added `*.json` to `.gitignore`. That would mean that `*.json` would be added to `.gcloudignore` causing all json file to ignored (even though the files could have been decoded/generated during cloud build steps)
- Convenience commands
  - Make commands to test locally
  - Make commands to fire pubsub messages
  - Make commands to alter topics/subscriptions
- Able to templatize conveniently without resorting to using git hacks etc or libs. (Previous methods involved relying on git providing to set one of the projects that you own as a template. Gitlab used to be able to allow to do this but that suddenly became a paid feature - a painful lesson indeed)

From above, it seems that creating a template would be nice. And in order to aid with this, there is a tool called `cookiecutter`. Here is a link to the project: https://github.com/cookiecutter/cookiecutter

This is a template that can be generated via `cookiecutter`: https://github.com/hairizuanbinnoorazman/cookiecutter-cloud-run-go

To use the tool, one can run the following after installing cookiecutter on your computer:

```
cookiecutter https://github.com/hairizuanbinnoorazman/cookiecutter-cloud-run-go
```

It is a prompt based cli tool; it would provide options that you can alter accordingly. This is an example of what it would like when you run it now:

```
cookiecutter https://github.com/hairizuanbinnoorazman/cookiecutter-cloud-run-go
You've downloaded /Users/hairizuannoorazman/.cookiecutters/cookiecutter-cloud-run-go before. Is it okay to delete and re-download it? [yes]: no
Do you want to re-use the existing version? [yes]: yes
golang_mod_name [github.com/sample/sample]:
mod_name [sample]:
app_name [sample]:
Select type:
1 - http
2 - msg
Choose from 1, 2 [1]:
```

There might be more options in the future as more features would be added to this template to support more complex cases.
