+++
title = "Using Service Accounts with RGA"
description = "Using Service Accounts with RGA"
tags = [
    "R",
]
date = "2017-03-21"
categories = [
    "R",
]
+++

RGA is one of the packages I often use in my line of work and I use it to extract data from Google Analytics Platform into R. From there, I can easily utilize data manipulation packages such as dplyr and tidyr to get the results I would need before pushing those results back to Googlesheets via the googlesheets R package.

However, one thing I found that could cause issues is the fact that packages such RGA and googlesheets R packages actually make use of your own credentials. It's convenient, but if there was a case where you leave the team/company then you can literally bid farewell to that script. The script will start to face authentication issues which render it useless.

One solution to this is to use a generic account which would be given access to all these accounts. This generic account would belong to the company and even if the person moves teams or companies, it would still leave the script working.

I wouldn't recommend that though; It feels like you're putting all your eggs in one basket solution. If that method was used, there would be a need do password maintenance on the account. There is also a possibility that users who have access to that account could use it for malice purposes and it would be hard to catch the person responsible, seeing that action will be performed by the "common" account.

Another solution is to actually use a service account. Google Cloud provides this so that supports server-to-server interactions such as those between a web application and a Google service. Link. This completely fits into our scenario where we actually have a script (which is a machine) talk to Google Analytics (which is also another machine)

Here's how to set it up:

- Get a Google Cloud Service Account
- Register that account into Google Analytics
- Access Google Analytics data via RGA

## Creating a Google Cloud Service Account

1.  Go to the following link to access Google Cloud . If you haven't registered for it before, just follow the drill of signing up for the service before you'll be able to access it. http://console.cloud.google.com/
2.  You do not need to have billing enabled for this. We are only going to create a service account which happens to be free.
3.  Click on the top left hand corner to access the menu

![gcloud-menu](/20170321_usingServiceAccountsWithRGA/gcloud-menu.png)

4.  Click on API manager

![gcloud-menu](/20170321_usingServiceAccountsWithRGA/gcloud-menu2.png)

5.  On this page, you can choose to support your own app credentials in order to support your RGA script. Select to enable to analytics API (this is the v3 of the Google Analytics API which RGA was still at during the time of writing this post)

![gcloud-menu](/20170321_usingServiceAccountsWithRGA/credentials.png)

6.  Click on the credentials (see above image). After which, you should see the next image

![gcloud-menu](/20170321_usingServiceAccountsWithRGA/credentials2.png)

7.  You will need to follow the next set of instructions to get your service account
    - Go to Oauth Consent Screen and fill up your product name (This seems to be only one that is necessary for now). You will need to do this or else you will not be allowed to create a service account.
    - Go back to the credentials selection (similar to the image above) and choose to make a new service account. You should see the following screen.

![gcloud-menu](/20170321_usingServiceAccountsWithRGA/serviceacc.png)

    You do not need to give your account any Google Cloud Compute Role but do give it a smart enough name. We would go with the default JSON key selection. After you do that, you can then create Create button. At this point, you will automatically download a json file (service account key) - DO NOT EVER LOSE IT. BUT IF YOU DO, JUST MAKE ANOTHER ONE.

8.  Take note of the Service account email (<Your service account name>@<Your project).iam.gserviceaccount.com
9.  That kind of concludes on the making of a Google Cloud Service Account

## Adding Service Account Credentials into Google Analytics

Ensure that you have an account to be able to edit permissions of the Google Analytics accounts and properties. If you do have that permission level, you would be able to just add users as usual to Google Analytics. Just follow the instructions here: https://support.google.com/analytics/answer/2884495?hl=en

If you do not do this step, the service account will not have access to the Google Analytics data and you would be unable to utilize it in your script.

## Access Google Analytics using the service account via R

And now, we finally can get to the code section of the Google Analytics data extraction!!

RGA doesn't really have service account capability. However, that wouldn't deter us from using this; internally, the package uses httr package for authentication purposes. httr does both the user authenticated way of doing things as well as the service account way of doing things. Only that the service account way of authenticating the service is not really exposed to you, the user.

```R
library(jsonlite)
library(httr)
library(RGA)

# Getting the token for future access to the account
endpoints <- httr::oauth_endpoints('google')
secrets <- jsonlite::fromJSON("./location-of-your-service-account-file.json")
scope <- 'https://www.googleapis.com/auth/analytics'
token <- httr::oauth_service_token(endpoints, secrets, scope)

# Utilizing the token to access the Google Analytics data
random_view_id <- '2134151'
RGA::authorize(token=token)
RGA::get_ga(random_view_id)
```

The code snippet only has 2 parts, the top portion is utilizing the httr package to authenticate the service account which would then provide the service account temporary access (token) to access Google Analytics data. While authenticating, you will not be seeing any Google Authentication Screen. Instead, the token value will just be created and assigned silently. This would be ideal if you are using this on a server to run some daily/weekly/monthly process of extracting and processing data on the server.

The bottom portion is the part of using the the token to actually hit the Google Analytics service to retrieve the data accordingly.

That's it for this tutorial in order to access the service account for the service. Happy trying!
