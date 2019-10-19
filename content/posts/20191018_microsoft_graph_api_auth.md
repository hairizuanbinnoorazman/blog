+++
title = "Microsoft Graph API Authentication"
description = "Doing up Oauth2 authentication in order to use Microsoft Graph API"
tags = [
    "microsoft",
]
date = "2019-10-18"
categories = [
    "microsoft",
]
+++

I've recently needed to find a way to use the Graph APIs offered by Microsoft in order to receive data and send data to the various Microsoft services. However, the documentation for it is pretty much scattered with various "depreciated" versions of the documentation everywhere. And the more weird thing is that there is emphasis to utilize the SDKs rather than calling the APIs directly. (I mean, its true that SDK makes it way easier to try it out by encapsulating API calls to be just function calls but sometimes, its kind of hassle to try to go understanding another library again.). It's really quite a pain to go find some relevant documentation on this.

If you're new to Oauth2 and if you find that you need to make calls to the API in some very specific way that the SDKs do not exactly cover, then, it would be best to just go look at Google's Oauth2 authentication. They are precise, easier to find and understand and they actually document the approach if you are going to do it via rest. Else, approaching this would require quite a bit of experiment work just to make it work. (Expect to see a lot of error 400 and not understanding which portion is the reason why its not working as expect)

I've dumped the most simplest version of a flask app that talks to Microsoft Graph API here if you need it for some reference.

Add the following code to `app.py`

```python
import json
import logging
import requests
from flask import Flask, request, redirect

app = Flask(__name__)

with open("config.json", 'r') as raw_data:
    config_data = json.load(raw_data)


@app.route('/')
def redirected():
    code = request.args.get("code")
    if code is not None:
        resp = requests.post("https://login.microsoftonline.com/{}/oauth2/v2.0/token".format(config_data["tenant_id"]), data={
            "client_id": config_data["client_id"],
            "scope": "https://graph.microsoft.com/User.Read",
            "code": code,
            "redirect_uri": "http://localhost:8000",
            "grant_type": "authorization_code",
            "client_secret": config_data["client_secret"]
        })
        logging.warning(code)
        logging.warning(resp)
        logging.warning(resp.content)
        return str(resp.content) + "\n" + code
    else:
        return 'Hello, World!'

@app.route('/login')
def login():
    return redirect("https://login.microsoftonline.com/{}/oauth2/v2.0/authorize?client_id={}&response_type=code&redirect_uri=http%3A%2F%2Flocalhost:8000&response_mode=query&scope=openid%20offline_access%20https%3A%2F%2Fgraph.microsoft.com%2Fuser.read&state=12345".format(config_data["tenant_id"], config_data["client_id"]))


@app.route('/hahax')
def final():
    return "HAHAX ENDED"


if __name__ == '__main__':
    app.run()
```

Don't forget to add this `config.json` file. Values are not added here for obvious reasons. Get your own.

```json
{
  "tenant_id": "FIND THIS VALUE ON AZURE PORTAL",
  "client_id": "FIND THIS VALUE ON AZURE PORTAL",
  "client_secret": "FIND THIS VALUE ON AZURE PORTAL"
}
```

Before you run this, make sure to go to Azure portal (even if you don't use Azure, you would still need to go there to activate the APIs and create the auth profiles for your account)

1. Azure Portal (https://portal.azure.com) -> Azure Active Directory -> App Registration
2. Create an application on App Registration
3. Click on the newly created app to manage it.
4. Near the top of the panel, there would be an endpoints button -> this would help you get the **authentication** and **token** endpoints that you would need in order to do Oauth2 logins for application. You would also get your **client id** here
5. Go to **Authentication** tab in order to add in your **redirect uris** that you would need to authenticate
6. Go to **Certificates & Secrets** tab in order to get the **client secret** that you would need to authenticate

Note, instructions that relate to UI are generally vague and imprecise, partly due to UIs generally way too often, making it hard to document them down reliably. In future posts, if there is ever a easy way to do it via CLI, then I would add it here.

After than, fill a `config.json` and run the python app.

This is a gist of what's happening:

1. User goes to `/login` endpoint of your server. This would redirect you to login your Microsoft account. Expect the usual microsoft interface here. You can imagine this to be similar to the
2. User logins to their account. Microsoft would redirect you using the `redirect uri` that you have specified in the Azure portal and in the request
3. You receive the `code` from the redirect from microsoft, combine it with another post request to exchange it for `access_token` and `refresh_token` etc. There is a lifetime to how long the token lasts to provide access on the user's behalf to the various Microsoft Graph APIs

Run the python code above with this:

```bash
FLASK_RUN_PORT=8000 flask run
```

The final response would be a html page that would show the json response containing `access_token` that you need to access the Graph APIs. Copy it add try it out with a curl command. I assume that you have at least added the necessary scopes on Azure portal to allow your app to query yourself to try things out. Refer to the scope in the root server call to see what scopes to add on Azure Portal

```bash
curl -H "Authorization: Bearer ACCESS-TOKEN-XXXXX" https://graph.microsoft.com/v1.0/me
```

With that, you would get a json response providing information about yourself as a user on the Microsoft account.
