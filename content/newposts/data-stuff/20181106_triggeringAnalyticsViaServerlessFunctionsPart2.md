+++
title = "Triggering analytics via Serverless Functions Part 2"
description = "Using Google Cloud Functions with Google Cloud Storage triggers to invoke analytics workloads"
tags = [
    "python",
    "google cloud",
]
date = "3018-01-01"
categories = [
    "python",
    "automation",
    "google cloud",
]
+++

Talking points:

- Mention about completing the challenge: How to trigger analytics from previously completely completed checks
- Talk the different ways it could be completed:
  - Once check is completed, store the state in a database, every dependent report that is run, it would check the condition of the states of the completed reports; if all completed, then run the compilation step
  - Everytime the check is completed, it would trigger the compilation; compilation would run a another check to ensure all is fine before running the report
