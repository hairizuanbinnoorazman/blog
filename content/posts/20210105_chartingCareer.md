+++
title = "Charting a career path in the tech world"
description = "Charting a career path in the tech world and navigating the various options available"
tags = [
    "personal",
]
date = "2021-01-05"
categories = [
    "personal",
]
+++

DISCLAIMER: The following article is just an opinion. Naturally, each person have their own work experiences that they can use to project their future plans; so take the items in this article with a large spoonful of salt when applying it into your own perspective.

- [Look to the business side as well](#look-to-the-business-side-as-well)
  - [Consultants](#consultants)
  - [Engineers in a product company](#engineers-in-a-product-company)
  - [Platform Engineers](#platform-engineers)
- [Narrowing down what to learn](#narrowing-down-what-to-learn)
  - [Referring to job roles before studying](#referring-to-job-roles-before-studying)
  - [Personal Projects](#personal-projects)
  - [Just do the interview](#just-do-the-interview)

# Look to the business side as well

When I first started my career in the technology track (software engineer, devops engineer), I initially thought that the only to move up the company hierarchy is to get good at what you do. So, in the case of being a software developer, that would probably mean being involved in writing up efficient and useful code that will be included into products. And maybe in the case of a devops engineer; be familiar with the various deployment platform and tools out there in the market. This does make sense in a way; as one gets better at their job, they would and should receive larger compensation packages. The experience and expertise that the engineer earned should allow the company to produce better services/products.

However, as with all things, it is good to broaden our perspective and look to the "business side" of things. At the end of the day, engineering skills aren't the ones that earning the paychecks. The products and services provided to customers are the ones that are earning the revenue for the company. By understanding the "business side" of things of the company, we can try to understand how revenue is earned and how it impacts the treatment we, as engineers, receive from a company.

This article is mostly going to look from an aspect of a software engineer and the various job options and routes available for him/her. However, even for other roles, it is pretty easy to try to apply the same methodoloy to understand future prospects - we would just need to understand how the money flows and how you as the engineer/employee is bringing value to the company (the organization that hired you).

Generally, from my roughly 4-5 years of working experience in this sector, I would roughly segment the job options as a software engineer in the following "job types". The business aspects of a company affects the role in various ways:

Let's approach each of the following categories one at a time

## Consultants

This job option is one where a software engineer that is employed in a company is not working in said company, but instead deployed to client companies. From this point onwards, essentially, you as the software engineer mostly report to the people in the client company, but salary, pay, benefits are handled by the company that employed you.

Before proceeding further, let's lay the common understanding that the company that would you to be deploy to client companies are "consultancy companies" whereas client companies are companies that pay good money to "consultancy companies" to get some sort of workforce

There are some good points with this arrangement:

- Easier to get attached to large, organizations which would provide learning opportunities to learn how large organizations operate

Of course there are some bad points to this arrangement:

- High chance that one would be working on the "boring" bits in a software engineering job. Think about it; if you were one of the tech directors of the client companies, would you rely on a transient sort of workforce to handle your core operations? (possibly interesting bits)
- Pay is supressed as compared to the rest of the industry. The company that employs you is the middleman here and needs to make a bit of profit by sending you to the client companies. That would mean that in order to compete properly, consultancy companies would need to try to lower their prices in order to make the contract appear like a better deal.

## Engineers in a product company

In the various product companies out there, one of the common roles would be backend engineers that would need to create the various features in the product that the company sell. In most cases, that would usually mean creating API services (because everyone is somehow into the microservices/REST way of doing things now) which would store data into some sort of database. In a simplistic sense, most of the apps out there are CRUD (create, read, update, delete) applications.

Not sure for you but in my opinion, it's kind of easy to get bored writing one crud app after another. Eventually, creating such apps would just mean copying and paste a whole chunk of code to get it the required application functionality.

Another bad thing that usually happens at this level of engineers in a product company is that product features that needs to be developed is dependent on external forces such as product sales/marketing. Sometimes, in order to win a certain contract, certain features are required to be created. The features required may be changed on whims on the customer, making the product requirements vague. This makes it hard to build the product required.

Some teams attempt to combat this by making features more "generalizable". But doing this would make feature development slower. More generalized features take more time to develop and such features requires even more time to test throughly.

There are some interesting bits but one would sometimes need to dig a little to get to such interesting bits:

- A application that is has pretty high usage and requires it to be scaled accordingly to handle the incoming workload. Scaling is usually pretty hard; at times, it may require you to deconstruct aspects of your applications (e.g. ORM in applications) and tweak them in order to create more efficient queries or introduce caching etc. However, it's important to note here that not all applications need to scale and not all applications to run and complete tasks "asap". It's better to focus more resources into applications that actually matter (the main revenue earning services) of the products that the company sell.
- Refactoring applications. To some, it is a necessary evil, but to others, it gives an opportunity to understand the codebase further. Before refactoring, we would need to understand that development work on the application will still need to continue; it cannot be put on a complete pause just for "refactoring". That would mean having the challenge of doing refactoring would mean slowly introducing new abstractions and slowly migrate away from old abstraction to utilize the new abstractions. I generally find that the following video explains this way better than what an article could cover: https://www.youtube.com/watch?v=h6Cw9iCDVcU

However, similar to the "consultancy" category of engineers, not all engineers are valued equally. Some engineers would appear to be "valued" by a company as compared to others. You can see from the kind of "interesting" problems being thrown at such engineers as well as faster promotion cycles. Why is this so?

I would boil to it all down to this one term: Leverage. You as an engineer would need to understand how your work would impact the company. Even if the impact is not in the monetary sense and is more on the "efficiency" sense, the value of such work still needs to be conveyed to upper management. The following video explains this way better: https://www.youtube.com/watch?v=SclqaNqqAV0

## Platform Engineers

Platform engineers are the engineers are that are usually far removed from the services that are "revenue" earning. However, they provide the core services that the rest of the company kind of relies on. Some of the services could be the customer management/identity systems, billing systems. These systems are core to the business of the company; any of them failing could be detrimental to the product/company.

With that, that would mean these engineers tend to receive and handle components that are challenging to manage and handle. Such services would need to scale well, be resilent to failures, less impacted by feature requests that may be required to be created to win deals etc. 

# Narrowing down what to learn

Let's set a case where you are some sort of frontend engineer and you're seeking to jump to backend engineering work (frontend got a bit too boring?). Or maybe if you are from another industry and you're trying to jump to the software engineering track. When you get online and check the various youtube videos/blogs, you would realize that there are many things that you would need to learn in order to be able to make that jump. Should you just hunker down and start learning everything?

This is the main issue with the software engineering career nowadays. After topic you will try to research online is just a rabbit hole waiting for you to discover. Reading up on just a subtopic will make you realize that you have another gap in another part of your knowledge. If you keep following, there is a high chance you'll just go around in circles; not full understanding everything online - and only being able to grab surface level knowledge which may not as useful to build up projects.

The following are kind of my personal suggestions to try in order to help narrow the amount of learning that you would need to do:

## Referring to job roles before studying

This method is metamorphically similar to looking at target and aiming for it. Instead of looking at the various technologies and attempting to understand the landscape, we would instead look at the role directly and try to understand what is involved in the role. From that, we can then try to understand what technologies would the job role require one to understand which we can then use to create the "study list" for us to utilize.

Let's take an example if we would want to apply for a job a Devops role. The role could mention that some of the job requirements could mention the following:

- Familiarity with Docker, Kubernetes
- Familiarity with Jenkins, Groovy scripts
- Strong scripting with Python, Bash
- Familiar with cloud platforms such as AWS

With the following job requirements, that would immediately reduce the scope of what we need to study. Instead of reading up on ways to deploying applications to Virtual Machines (systemd etc), we can focus on containerization technologies such as Docker. And since there is a mention of Python, Bash and Groovy scripts; that would define the languages or tools that we would need to master.

This can be applied to almost any tech job; as time goes by, your previous roles may overlap future roles and would make it even easier to search for newer roles.

## Personal Projects

Just reading up on concepts and tools is usually insufficient to internalize how a tool/library/programming language works. In my opinion, the best way to do so is to actually to run the it on your own workstation or to try out it in various use cases.

One example that I have in my personal experience is in regards to understanding how Kubernetes works. If we have tried to read from online resources, it would just say that Kubernetes is a platform that orchestrates containers. If we had just read that and then just regiterate that to our interviews, it becomes clear that we don't fully understand how the tool works or why an organization would want to use it.

So, if we want to understand Kubernetes, we would need to understand what a container is. And to understand what a container is, we may need to look into Docker containers and then from there we may look into how we create a docker container, how an app relates to it, how to get an app and database to work with the platform and what would be a good way to work with it.

Getting the knowledge and understanding the complexity of the tool takes experience of using the tool and in my opinion, there is no better way then to have a end to end experience with it. This involves creating an application, putting it into a docker container and getting the docker container into the kubernetes cluster.

We can say the same for almost any piece of tech that we may wish to learn. Let's say we feel that in the future, serverless platforms offered by cloud platforms would be a big deal with most companies using it in the future. Should we just stop at just reading up on the various offerings provided by the various platforms? Or should we go the extra mile to try deploying applications using the serverless platform? If we had gone with the latter, we would experience some of the issues with relying on such platforms (e.g. cold starts, dealing with dependencies, developing of app in a team based environment - no local environment)

## Just do the interview

As the title of this section says, just go ahead and proceed with the interview. The experience of going through with the interview also gleans a whole bunch of learnings although it involves hardening your heart against failing the interview and looking bad to your interviewers.

So why this approach? If you just go along with the above approaches, (e.g. approach 1 of using job posts and learning technologies based on job requirements), there is a very high likelihood that you would only cover surface level concepts of said tools. It could be surface level knowledge may not be enough for such roles; you might need to "go deeper" down the stack and have a appreaciation for the underlying technologies that power the tool. You will only glean such insight by going through interviews. At the same time, you may get the motivation to learn more from the feelings of regrets of being unprepared from the interview, thereby solidifying your knowledge and concepts further.