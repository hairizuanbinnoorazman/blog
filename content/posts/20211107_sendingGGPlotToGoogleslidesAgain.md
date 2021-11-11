+++
title = "Sending ggplot graphs to googleslides again"
description = "ggplot graphs to googleslides via rgoogleslides but using Google Cloud Storage"
tags = [
    "r",
    "rgoogleslides",
    "google-cloud",
]
date = "2021-11-07"
categories = [
    "r",
    "rgoogleslides",
    "google-cloud",
]
+++

There was a change to the Google Slides API that resulted in an inability to upload images from Google Drive into Google Slides programmatically. Refer to the following issue on the rgoogleslides github repo - https://github.com/hairizuanbinnoorazman/rgoogleslides/issues/28. 

Seeing how the state of the issue didn't change over a year, personally I don't think there will be any change/fix coming along. I guess the only way to get about this is to have some sort of workaround to try to deal with it.

So, before going deeper into this, first we need to understand why people want this "images" in Google Drive and be "injected" into Google Slides. The Google Slides that allow injection of the images into Slides accept a URL but previously, accepts a Drive ID of an image. For the URL, it has to be "public" or at least but Google Servers to fetch the image over into the slides. This won't be ideal if the image is some sort of graph that we generated from our data. We wouldn't want this image to be public at all. Fortunately, the Drive ID was available then which allowed users to add images into user's Drive which can then be programmatically added to Google Slides. The image will never need to be exposed publicly.

However, now that this mechanism is "broken" - we would need some sort of workaround. We need a way to have the image that we wish to remain private to be available publicly "publicly" and have some sort of "credentials" to ensure that no one would accidentally come along and get the image by accident. 

One way I can think of is to add image into a Nginx server and temporarily serve it with some sort of "key" as a parameter in the URL. However, the setup for this seems a bit of hassle for the average user of this package. A data analyst generally wouldn't deal too much with servers etc.

Another way is to actually utilize S3 based storages (e.g. Google Cloud Storage or AWS S3). Luckily, the APIs for those are pretty clear and its usage is pretty defined. The mechanism that make this ideal is that it is possible to keep images under "lock and key" most of the time. We can use the "signed URLs" mechanism which generates a very long URL endpoint which makes it unlikely for someone to guess it. We can set the "signed URLs" to be expired in 5 mins as well to limit the chance of anyone trying to brute force getting the image. The following post will showcase how to do this. 

This blog post is using the previous example [Sending GGPlot to Google Slides](/sending-ggplot-graphs-to-googleslides/)

## Setting up authentications

You would need to get the following:

- Client ID and Client Secret for RGoogleSlides package - Desktop. Refer to the following link: [Link](/rgoogleslides-using-your-own-account-client-id-and-secret/) - no roles is needed here
- Service Account with "Storage Object Admin"
- Enable Google Drive API
- Enable Google Slides API
- Enable Cloud Storage API

## The Script

We first initialize the libraries that we'll need for this exercise

```R
library(rgoogleslides)
library(googleCloudStorageR)
library(ggplot2)
library(png)
```

The next step is need for googleCloudStorageR - it apparently needs to look for the following environment variables when trying to create the Signed URL

```R
Sys.setenv("GCS_DEFAULT_BUCKET" = "XXX-BUCKET-NAME-XXX")
Sys.setenv("GCS_AUTH_FILE"="/XXXXXX/service-account.json")
gcs_global_bucket("XXX-BUCKET-NAME-XXX")
```

The next step would be create the image of the plot which we would be sending to the slides

```R
# Do up a quick plot on iris dataset
first_plot <- qplot(iris$Sepal.Length, iris$Sepal.Width, color = iris$Species)
ggsave("first_plot.png", first_plot)

# Determine the dimensions of the image
image <- png::readPNG("first_plot.png")
dimension <- dim(image)
image_width <- dimension[1]/8 # Calculate to your requirements
image_height <- dimension[2]/8 # Calculate to your requirements
```

Image height and width is needed in order to calculate how to position the image on the slides. It will be used at the end.

Next would be to authorize both R googleslides as well as Cloud Storage R packages

```R
rgoogleslides::authorize("XXX-CLIENT-ID-XXX.apps.googleusercontent.com", "XXX-CLIENT-KEY-XXX")
googleCloudStorageR::gcs_auth("auth.json")
```

We would then upload the image to Google Cloud Storage. With the uploaded image - we can use the returned metadata to generated the signed URL

```R
aa = googleCloudStorageR::gcs_upload("first_plot.png", predefinedAcl = "bucketLevel")
signedURL = gcs_signed_url(aa)
```

The value of the signedURL can be used in the browser - it should allow you to just view you as it is. The link by default is valid for 1 hour but we can shorten as necessary.

The next step would be to create the slides and then to inject the image into it

```R
# Create a new googleslides presentation
slide_id <- rgoogleslides::create_slides("Test Analysis NEXT")
slide_details <- rgoogleslides::get_slides_properties(slide_id)

# Obtain the slide page that the image is to be added to
slide_page_id <- slide_details$slides$objectId

# Get the position details of the element on the slide
page_element <- rgoogleslides::aligned_page_element_property(slide_page_id,
                                                             image_height = image_height,
                                                             image_width = image_width)
request <- rgoogleslides::add_create_image_request(url = signedURL, page_element_property = page_element)
response <- rgoogleslides::commit_to_slides(slide_id, request)
```

Notice the `signedURL` variable being used as well as the `image_height` and `image_width` variables.

Within the response variable, it should provide the Slides ID of where the Slides are created

## Full script

The full script is as follows (without the explanation)

You would need to substitute in the values as needed by the script

```R
library(rgoogleslides)
library(googleCloudStorageR)
library(ggplot2)
library(png)

Sys.setenv("GCS_DEFAULT_BUCKET" = "XXX-BUCKET-NAME-XXX")
Sys.setenv("GCS_AUTH_FILE"="/XXXXXX/service-account.json")
gcs_global_bucket("XXX-BUCKET-NAME-XXX")

# Do up a quick plot on iris dataset
first_plot <- qplot(iris$Sepal.Length, iris$Sepal.Width, color = iris$Species)
ggsave("first_plot.png", first_plot)

# Determine the dimensions of the image
image <- png::readPNG("first_plot.png")
dimension <- dim(image)
image_width <- dimension[1]/8 # Calculate to your requirements
image_height <- dimension[2]/8 # Calculate to your requirements

rgoogleslides::authorize("XXX-CLIENT-ID-XXX.apps.googleusercontent.com", "XXX-CLIENT-KEY-XXX")
googleCloudStorageR::gcs_auth("auth.json")

aa = googleCloudStorageR::gcs_upload("first_plot.png", predefinedAcl = "bucketLevel")
signedURL = gcs_signed_url(aa)

# Create a new googleslides presentation
slide_id <- rgoogleslides::create_slides("Test Analysis NEXT")
slide_details <- rgoogleslides::get_slides_properties(slide_id)

# Obtain the slide page that the image is to be added to
slide_page_id <- slide_details$slides$objectId

# Get the position details of the element on the slide
page_element <- rgoogleslides::aligned_page_element_property(slide_page_id,
                                                             image_height = image_height,
                                                             image_width = image_width)
request <- rgoogleslides::add_create_image_request(url = signedURL, page_element_property = page_element)
response <- rgoogleslides::commit_to_slides(slide_id, request)
```

## Suggestions

A few suggestions while trying to use the following mechanism as a common operating framework to automate sending of plots to Googleslides

- Set a shorter expiry time of the Signed URLs to 5-10 minutes (depending on how long before script can be completed)
- Set a lifecycle rule on objects to be "deleted" after 1 day of expiry. This reduces the need to cleanup the images from the bucket. The storage bucket is just a "cache" for the images, we generally would be regenerating the images for future plots from the code base.



