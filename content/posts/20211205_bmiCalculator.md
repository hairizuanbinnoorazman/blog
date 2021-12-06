+++
title = "BMI Calculator"
description = "BMI Calculator built with Elm frontend embedded into Hugo Static Sites"
tags = [
    "hugo",
    "elm",
    "personal",
]
date = "2021-12-05"
categories = [
    "hugo",
    "elm",
    "personal",
]
+++

BMI or Body Mass Index is calculated by taking one's weight (in kilogram) and divided by the square of the height of the person (in metres). You can utilize the following tool below to quickly calculate this.

{{< bmi_calculator >}}

The are 4 states for BMI calculations; Underweight, Normal, Overweight and Obese. 

If you were underweight, it would best to check your diet to ensure that your body is receiving sufficient nutrition to ensure a healthy body to prevent diseases such as nutritional deficiency or osteoporosis. Do seek medical advice if necessary.

However, if you were overweight or obese, it is vital to begin to check diet and exercise to try to begin to lose weight over a time period. Being obese or overweight over long periods is worrisome - when you're young, your health problems won't be too obvious but it'll worsen as time marches on.

__Privacy Notice: The following tool will not record any details and is not sent to any server. All calculations are done within browser.__

The statictics for diabetes looks relatively grim in Singapore; and it rose to the point where the country wanted to wage [War on Diabetes](https://www.healthhub.sg/live-healthy/1273/d-day-for-diabetes). One of the factors to reduce the incidence of this is to ensure a healthy body weight - which is judged by calculating BMI (Body Mass Index)

In the case for Singaporeans (Asians), the ideal BMI currently is __23__. Previously, it used to be 25 (just making use of research done on a mostly western audience), but further studies indicate of differnet fat/muscle composition differences between populations. Refer to some of the studies here: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5571887/

## Technical details of BMI tool

This section has nothing to do about BMI etc; it would be detailing how the BMI calculator is embedded into the following site.

The following BMI calculator on this page is built on ELM and then embedded into Hugo. Do refer to the details by checking the following page: [ELM Frontend in Hugo Static Site](/elm-frontend-in-hugo-static-site/)

In the future, the tool would be improved to accept various weight/height in various units such as pounds or feet/inches.
