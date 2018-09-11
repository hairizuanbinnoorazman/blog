+++
title = "Matching object ids in elements on a Googleslide"
description = "Using object ID element to manipulate elements in rgoogleslides "
tags = [
    "r",
    "rgoogleslides",
]
date = "2017-06-19"
categories = [
    "r",
    "rgoogleslides",
]
+++

While attempting to play around with object ids via the rgoogleslides package, the main issue I got was to quickly understand which object id referred to which element on the slide?

It was possible to retrieve the list of objects on a page in a google slide but there was too much nested structures in the response of the google slides api in order to understand what was going on in the slide.

In order to simplify the process, I am experimenting with an abstraction on top of understanding this nested. This would immediately give immediate information such as the object ids of text boxes or object ids of tables.

![package-image](/20170619_matchingObjectIDElementGoogleslide/slides_tables.png)

Let's say we have the above slide as an example.

If we were to run the get_slide_page_properties function with the upcoming rgoogleslides version 0.3.0, it would return the following object.

```R
library(rgoogleslides)
rgoogleslides::authorize()

# Slide id refers the id of the entire slide deck
slide_id <- "aaaaaa-hidden-id-aaaaaaaa"

# Slide page id refers to the specific slide within the slide deck
slide_page_id <- "p"

slide_data <- get_slide_page(slide_id, slide_page_id)

slide_data
# <SlidePage>
# Public:
# clone: function (deep = FALSE)
# get_tables: function ()
# get_text_boxes: function ()
# initialize: function (slide_page_list_response)
# raw_response: list

slide_data$get_text_boxes
#  object_id text_content
# 1 g1e4756099b_0_1 Test - Finding out the object ids of each element on this page\n

slide_data$get_tables
# [[1]]
# [[1]]$object_id
# [1] "g1e4756099b_0_5"
#
# [[1]]$table
# X1 X2 X3 X4
# 1 Test1\n Test3\n Test4\n Test5\n
# 2 Test2\n
# 3
# 4
```

With a single glance, it is possible to know that object id `g1e4756099b_0_1` refers to the text box and `g1e4756099b_0_5`. The following information is just data being parsed by an object which checks the data type of each of the object id as well as to retrieve all the data required in order to identify the different elements within the slide.

With that, we can then apply the following changes:

- Delete the text from the text box
- Insert new text into said text box

```R
library(rgoogleslides)
rgoogleslides::authorize()

# Slide id refers the id of the entire slide deck
slide_id <- "aaaaaa-hidden-id-aaaaaaaa"

request <- add_delete_text_request(object_id = "g1e4756099b_0_1")
commit_to_slides(slide_id, request)

request2 <- add_insert_text_request(object_id = "g1e4756099b_0_1", text = 'Testtesttest')
commit_to_slides(slide_id, request2)
```

I guess it is easy to image the result of the above code snippet; it would just replace the text box with the `Testtesttest` text.

This set of changes is set to come with version 0.3.0 of the rgoogleslides package which should be coming quite soon.
