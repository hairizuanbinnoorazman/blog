+++
title = "A sample bookcase application case"
description = ""
tags = [
    "golang",
]
date = "2018-03-07"
categories = [
    "golang",
    "web",
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
- User activate emails by clicking on link in the email
- User is now active

User forgotten password
- User clicks forget password
- Email sent to user (Forgot password expiry activated with its respective token)
- After clicking on email for forgot password email, if before the forgotten expiry time, allow the password change, else; no change to the password

Initial thoughts on construction of the API layer:
- Products (List, Get, Add, Subtract, Modify - qty,description,status,etc)
- User (List,Get,Add,Modify) - Should not have delete operation
- Orders (List, Get, Add, Modify)
- Subscriptions/Wishlist (List, Get, Add, Modify)

# List of database fields

## User

Fields
- ID
- First Name
- Last Name
- Email
- Password
- Facebook ID (Optional)
- Twitter ID (Optional)
- Google ID (Optional)
- Permissions
- isActive status
- activationCode
- forgotPasswordExpiry
- forgotPasswordToken
- Created Time
- Updated Time
- Last Login Time

Some constraints set on the user struct:
- First name: Must not be empty, must be less than 100 characters
- Last name: Must not be empty, must be less than 100 characters
- Email: Must follow the email regex (Includes @ and domain at the end)
- Password: Password length > 8; Must contain at least small characters, Capital letters and a number

## Permissions

Fields
- ID
- Name of permission (UpdateProductField,ViewProductField,Public etc)
- Description
- Status
- Remarks
- Created Time
- Updated Time

Some constraints set on the permissions struct:
- Name of permission: Must not be empty, must be less than 150 characters
- Description: Must not be empty, Text field is sql
- Status: Only the following strings are allowed in: ['active', 'inactive', 'depreciated']

## Role

Fields
- ID
- Name of role
- Description
- Created Time
- Updated Time

Some constraints set on the role struct:
- Name of role: Must not be empty, must contain any one of the following strings: ['admin', 'member', 'editor', 'view']
- Description: Must not be empty, Text field

## Role x Permission Mapping

Fields (Many:Many relationship)
- Role ID
- Permission ID

## Items

Fields
- ID
- Name of Product
- Short Description
- Long Description
- Product Category (Foreign Key)
- Product Subcategory (Foreign Key)
- Created Time
- Updated Time

## Product Category
- ProductCategoryID
- Name of Product Category
- Description
- Remarks
- Created Time
- Updated Time

## Product Subcategory
- Product Subcategory ID
- Name of Product Subcategory
- Description
- Remarks
- Product ID
- Created Time
- Updated Time

## Supplier ID 
- ID
- Supplier Name
- Description
- Supplier Main Contact
- Supplier Secondary Contact
- Supplier Email
- Country
- Created Time
- Updated Time



