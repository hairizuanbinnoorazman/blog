+++
title = "Custom Endpoint for Google Analytics data with Golang"
description = "Creating a custom endpoint for Google Analytics data with Golang"
tags = [
    "golang",
]
date = "2023-02-28"
categories = [
    "golang",
]
+++

## Introduction

I used to work with Google Analytics to obtain site analytics for websites and android application. Technically, the current blog is monitored using Google Analytics. Monitoring of website data is generally useful as it provides information to the authors of the website/website owners on what particular content that website visitors find the most useful. With such information, it makes easier for the owner to try to add new content that attempts to provide such relevant content to visitors which would hopefully spur a virtuous cycle of gaining more audience for the website.

One of the irriting bits when working with Google Analytics is that in general, you wouldn't have easy access to the raw data that is being collected from the website. For most users of Google Analytics, they might not need it too much; however, it may be pretty important for bigger and more sophisticated users of the tool. They may want to augment the raw data with even more custom data so that their analysis of such website visit data might be more useful but raw data access is quite hard to achieve. In some cases, one can access raw data but it requires paying a pretty expensive business plan (maybe it may not be relevant now but this was true in the past - they is a premium plan which is based on amount of data that is being collected by the Google Analytics tool)

One of the random things I did wonder about was the possibility of circumventing the need to pay for paying an expensive plan just to obtain data that you otherwise are supposed to freely access. But before we get to that stage, we would first need to understand slightly on how one even collects data via the Google Analytics tool in the first place.

In order to collect website visitation data from a website using Google Analytics, you would first need to create some sort of "analytics account" that would be used to identify on what "business" we're trying to monitor. Once the "account" is created, we can enter it and then retrieve information such as Javascript snippet which would need to be embedded into our website in order to start collect information. The javascript snippet would retrieve actual javascript functions over the internet from Google Analytics servers that would then run http GET/POST requests to the Google Analytics servers which would then collect and collate such information on the servers.

By default, the Google Analytics javascript that is to be added to the website would usually point to Google Analytics servers but it would be nice if we can simply "hijack" the functionality and instead, point it to our own custom endpoint - which would automatically mean that we are collecting raw data. This would mean that we have to handle the hard work of sorting and storing all that data (if there is a ten million data points coming in each month, how should handle and store such data? And how should it be stored such that it would be easy to query in the future etc)

Interestingly enough, there is a way to set a custom endpoint for Google Analytics Javascript snippet. The details of how this is done is available in the following blog post: https://www.simoahava.com/gtm-tips/send-google-analytics-requests-custom-endpoint/. We won't go through the methodology of how Google Analytics work etc but we're just demonstrating of how we can configure a Google Analytics Javascript to sent such analytics http requests to a custom endpoint on a Golang service.

## Configuring it

The first part is first define our html templates that would represent our "website". These are simple html pages. We would also define our analytics javascript snippet as a template that would injected into other templates (so that we don't have to copy it everywhere). 

Our JS Snippet - the snippet is obtained from the Google Analytics "analytics account" that we would need to manually create. Do note the slight difference here where we added additional configuration in the last `gtag` function call. The `transport_url` would be the parameter for where we would be sending the Google Analytics http requests to. The `forceSSL` parameter would be whether to have the snippet force to "promote" all http requests to "https" requests. Https requests is definitely a good default but for testing purposes, it would always be nice to avoid this - since its a pain to setup.

This is saved as "header.tmpl" file

```golang
{{define "analytics2"}}
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'G-XXXXXXXX', {
    transport_url: 'http://localhost:8080/analytics',
    forceSSL: "false",
  });
</script>
{{end}}
```

Our main "index.tmpl" file. It would injected our analytics snippet in.

```golang
{{define "index"}}
<html>
    <head>
    {{template "analytics2"}}
    </head>
    <body>This is index page</body>
</html>
{{end}}
```

Our main golang file would be this. Don't forgot to set up Golang modules for the Golang project to prevent further problems further down the line

```golang
package main

import (
	"log"
	"net/http"
	"text/template"
)

type basicWebsite struct{}

func (b *basicWebsite) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	files := []string{
		"./templates/header.tmpl",
		"./templates/index.tmpl",
	}
	ts, err := template.ParseFiles(files...)
	if err != nil {
		log.Print(err.Error())
		http.Error(w, "Internal Server Error", 500)
		return
	}
	err = ts.ExecuteTemplate(w, "index", nil)
	if err != nil {
		log.Print(err.Error())
		http.Error(w, "Internal Server Error", 500)
	}
}

type GoogleAnalyticsParameters struct {
	// General
	ProtocolVersion string `json:"protocol_version"`
	TrackingID      string `json:"tracking_id"`
	// User
	ClientID string `json:"client_id"`
	// Content Information
	DocumentLocationURL string `json:"document_location_url"`
	// System Info
	ScreenResolution         string `json:"screen_resolution"`
	ViewportSize             string `json:"viewport_size"`
	UserLanguage             string `json:"user_language"`
	UserAgentArchitecture    string `json:"user_agent_architecture"`
	UserAgentFullVersionList string `json:"user_agent_full_version_list"`
	UserAgentMobile          bool   `json:"user_agent_mobile"`
	UserAgentModel           string `json:"user_agent_model"`
	UserAgentPlatform        string `json:"user_agent_platform"`
	UserAgentPlatformVersion string `json:"user_agent_platform_version"`
	// Hit
	HitType           string `json:"hit_type"`
	NonInteractionHit bool   `json:"non_interaction_hit"`
}

type analytics struct{}

// Reference:
// https://www.thyngster.com/ga4-measurement-protocol-cheatsheet/
func (a *analytics) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	log.Println("start processing analytics request")
	defer log.Println("end processing analytics request")

	ga_params := GoogleAnalyticsParameters{}
	// General
	ga_params.ProtocolVersion = r.URL.Query().Get("v")
	ga_params.TrackingID = r.URL.Query().Get("tid")
	// User
	ga_params.ClientID = r.URL.Query().Get("cid")
	// Content Information
	ga_params.DocumentLocationURL = r.URL.Query().Get("dl")
	// System Info
	ga_params.ScreenResolution = r.URL.Query().Get("sr")
	ga_params.ViewportSize = r.URL.Query().Get("vp")
	ga_params.UserLanguage = r.URL.Query().Get("ul")
	ga_params.UserAgentArchitecture = r.URL.Query().Get("uaa")
	ga_params.UserAgentFullVersionList = r.URL.Query().Get("uafvl")
	if r.URL.Query().Get("uamb") == "1" {
		ga_params.UserAgentMobile = true
	}
	ga_params.UserAgentModel = r.URL.Query().Get("uam")
	ga_params.UserAgentPlatform = r.URL.Query().Get("uap")
	ga_params.UserAgentPlatformVersion = r.URL.Query().Get("uapv")
	// Hit
	ga_params.HitType = r.URL.Query().Get("t")
	if r.URL.Query().Get("ni") == "1" {
		ga_params.NonInteractionHit = true
	}

	log.Printf("%+v\n", ga_params)

}

func main() {
	http.Handle("/index", &basicWebsite{})
	http.Handle("/analytics/collect", &analytics{})
	http.Handle("/analytics/g/collect", &analytics{})
	log.Fatal(http.ListenAndServe(":8080", nil))
}

```

Our website has 2 main endpoints. The `/index` endpoint would be our main entry point for website. That would load up `index.tmpl` templates and showcase the javacript calls. The analytics http requests would be sent to `/analytics/g/collect`. The analytics requests url would usually be GET http requests with plenty of query parameters - which why we see a large function for attempting to parse the query parameters and getting the appropiate data from the URL. Even so, this doesn't cover all possible query parameters; there are plnety of them that wasn't even covered here - might be covered in a future blog post of where we can use this custom mechanism to capture analytics from random events such as clicking of a button.

## Reference

For reference of how the server would look like, we can refer to the following github link (to this specific folder - the code for the folder may move in the future, just explore around the repo to find the most relevant codebase related to this)

https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/analytics