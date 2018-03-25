+++
title = "A sample bookcase application case"
description = ""
tags = [
    "golang",
]
date = "2018-03-07"
categories = [
    "golang",
]
+++

We would try to implement the various technology stack for some common web application scenario in several types of libraries. In our case here, we would attempt to implement it for the following scenario.

# Introduction

The web application contains the following features:
- An E-Commmerce web application (On a high level overview)
- For backend portions done in languages such as Python or Golang or Java, only the API Backend will be built. A stack that has both frontend and backend in one will not be used here.
- Email integration for certain user interactions on the website
- API Endpoints have permission checks. Probably can use the decorator method to set which API is to be protected by which -> Error 403 for those that do not connect accordingly.

User Registration Flow
- User sign ups with email and password. Email sent to user
- User can go into portal (But does not permission to do plenty of stuff?) - user is still inactive
- User activate emails by clicking on link

Initial thoughts on construction of the API layer:
- Products (List, Get, Add, Subtract, Modify - qty,description,status,etc)
- User (List,Get,Add,Modify) - Should not have delete operation
- Orders (List, Get, Add, Modify)
- Subscriptions/Wishlist (List, Get, Add, Modify)

# List of database fields

User
- ID
- First Name
- Last Name
- Email
- Password
- Facebook ID
- Twitter ID
- Google ID
- Record Creation Time
- Permissions
- isActive status

Permissions
- ID
- Name of permission (UpdateProductField,ViewProductField,Public etc)

Product Fields
- ID (UUID)
- Name of Product
- Short Description
- Long Description
- Product Category (Foreign Key)
- Product Subcategory (Foreign Key)
- Qty
- Price
- Cost Price
- Supplier ID

Product Category
- ProductCategoryID
- Name of Product Category

Product Subcategory
- Product Subcategory ID
- Name of Product Subcategory
- Product ID

Supplier ID
- ID
- Supplier Name
- Supplier Main Contact
- Supplier Secondary Contact
- Supplier Email
- Country



