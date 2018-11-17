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

This is a continuation of previous [blog post]({{< ref "20181106_triggeringAnalyticsViaServerlessFunctionsPart1.md" >}}).

To summarize the previous related blog post.

- Too painful to have people respond and react to report generation and compilation
- Too expensive to have machine lying around to pick up the slack and automate the reports; serverless solutions (pay on use) could be a useful model to use when running automated reports.
- Scenario presented for example purposes: 3 reports generated which are to be compiled to a single report. Previously mentioned 3 reports would be processed on the condition when the data files are dropped into the storage buckets. Event generated from it would automatically run the report

## Compilating reports

The next part of resolving our above mentioned situation (read previous blog post - part 1 for more details on this) is to compile the report. There are several ways to handle, each with their own advantages and drawbacks respectively. We would use the terms `subreport` to refer to reports for the initial set of reports that would then need to be compiled into a final `report`. These are just possible solutions; the combination of products that can be used to achieve the final goal of checking subreports and then compiling into the final report.

- Solution 1: On each time when a subreport is submitted and a check is run, we would run the function which would check the subreport. Afterwhich, we would then save the info that we checked the subreport into some sort of data storage (database). On each hour, we would run another function that would check the database; once all the subreports are ready, we would then do the compilation of the reports and then, we would be done for the day.

  - Issue: We would probably need to rely on another service: Google Cloud Scheduler (just released) which would maintain the cron schedule. That would trigger the google cloud function to run an hourly basis to check

- Solution 2: On each time when a subreport is submitted and a check is run, we would also run a check on the other subreports. Once they are all complete, we would then add a message on Google Pubsub. This would allow us to trigger another Google Cloud Function that would do the compilation of subreports which would then be used to generate the final report.
  - Issue: With the above method, we would need to recheck all subreports on each submission report. That would result in wasted computation where we would need to keep rechecking all subreports each time. It would ideal to store the information that some of the subreports have been checked to prevent computation from being wasted from checking data
