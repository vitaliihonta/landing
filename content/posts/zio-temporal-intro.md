---
title: "Temporal Workflows with ZIO: Introduction"
date: 2023-09-01T10:00:00+02:00
series: "Temporal Workflows with ZIO"
draft: false
tags: ["Temporal", "ZIO"]
---

## Introduction
Do you spend a lot of time making your applications resilient? Dealing with distributed state and locks? Migrating from sync to async communication? Adding retries, tracing?  

That's a usual programming routine that we, as engineers, must care about. On the other hand, it shifts our focus to technical issues instead of the original bussiness problem.  

Can we change the status quo? Are there any tools or instruments to help us struggle less and to be more productive?  

Meet [Temporal](https://temporal.io) — a distributed workflow management system for building invincible apps. It handles most technical problems, such as scaling, transactivity, managing state, etc. Temporal lets you focus on business needs and produce value quickly.  

[ZIO Temporal](https://zio-temporal.vhonta.dev/) is a *Scala SDK* for Temporal implemented with [ZIO](https://zio.dev). It allows working with Temporal naturally (like it was developed for Scala). It handles most typical programmer errors at compile time. It also brings seamless ZIO interop!

In this series of articles, you will see how to solve *kinda* real business problems using the concept of *Workflows*. 


## About the business problem
We're going to develop a **Content synchronization platform** (let's call it the **content sync app**).  
**TL;DR** the source code is already available on [GitHub](https://github.com/vitaliihonta/zio-temporal-samples/tree/main/content-sync)

### User story
**As a regular person**, I struggle to check various sources of content (newsletters, videos on YouTube, etc). I wish there were an aggregator fetching *content I want* and making recommendations for me. For instance, a [Telegram Bot](https://telegram.org/faq#bots)

### Technical details
While it sounds pretty easy, the content sync app requires a thoughtful design *in case reliability and scalability are a requirement*.  

The components of such a platform can be defined as follows:
- *Data ingestion* component that is responsible for *fetching the data*. For simplicity, let's call it **puller**
- *Data processing* component that is responsible for getting value out of data and for making recommendations for the end users. Let's call it **processor**
- *Frontend API* serving the data for users. In our case, it's gonna be the Telegram Bot interacting with the end user. Let's call it simply **telegram bot**.

Those components require:
- *Scheduler* to trigger the execution of components
  - Note: that's the requirement, as many content sources don't support real-time updates streams
- *Syncrhonization mechamism* to run and supervise the content sync process end-to-end
- *Reliability* facilities in each component to guarantee proper error handling, retries and isolation (to localize the possible impact of errors, therefore avoiding global outages)
- *Storage layer* for raw data and processed data (can be the same or two separate storages)
- *User session store* for internal application-level data (for UI-related functionality). 

Taking those requirements into account, at the first glance, we might need:
- Scheduler library like [Quartz](http://www.quartz-scheduler.org/) with a relation database for persistency
- File system for raw data
- Relational database (such as Postgres) for processed data
- Message Queue (like RabbitMQ or Apache Kafka) for intra-component communication
- Key-value store like Redis for session data

It's a pretty big list of components to maintain, isn't it?  
*No need for this*. **Temporal platform** can reduce this list to just:
- Temporal cluster
- File system
- Relational database

## What is Temporal?
Temporal is an **open-source workflow management system**. 
Temporal Application *implements* the business logic in terms of **Workflows**.
Workflows are then executed by the **Temporal Server** that takes care of retries, persistency and so on.

### Workflow vs Activity
Two main building parts of Temporal are **Workflow** and **Activity**.   

**Workflow** is the business process definition represented as code.  
**Activity** is all the hard work and technical details.  

*Activities* perform error-prone operations (such as interactions with external systems and APIs), complex algorithms, etc. 
*Workflows* implemented the business logic using *Activities*. A *Workflow* can also spawn and supervise *Child Workflows*.  

### Workflow particles
The *Workflow* consists of the following particles:
1. **Workflow method** that executes the whole business logic
2. **Signal method** that allows to interact with a running workflow from the outside
3. **Query method** that allows inspecting the business process state

The *Workflow* logic is described with code, so you're free to use any constructs of your favorite programming language as long as it is **Deterministic** (we will talk about this later).

### Workflow execution
Workflows are executed by the **Temporal Server**. 
Client-side applications schedule Workflow execution via Temporal Server API.  
*Temporal Server* then routes the Workflow to a **Task Queue** (specific by the client-side), so that a **Worker** application can pick it up.
*Workers* execute the *Workflow* logic code. Whenever a *Workflow needs* to execute an *Activity* (or *Child Workflow*), the *Temporal Server* executes it (via the same Worker or another one) and **stores the result** in the *Event storage* (usually a database).  
*Workflow* can suspend its execution for some time until a *Singal* received or a certain condition is met. The *Worker* doesn't waste resources while a *Workflow* execution is suspended.  

This is a very powerful approach, allowing reliable retries of failed *Workflows*. 
For instance, in case the *Workflows* invokes two *Activities*, if the *first Activity* invocation succeeds, but the *second* one fails, **only the second is retried**. Remember, the result of the first Activity invocation is persisted into an event storage, so there is no need to retry the entire *Workflow*. The same logic applies to *Child Workflows*.

Let's go back to the *Determinism restriction* for the Workflow logic. In case of failures, the Workflow execution will be retried by the Temporal Server. The steps that succeeded won't be re-executed (as stated above). Instead, the Workflow code will operate with the results from the Event storage.  
Therefore, it is important for the Workflow logic to act deterministically so that the flow goes the same way given historical events.  
**All non-deterministic code must be encapsulated into Activities**.   

## Content Sync Architecture
Now we can go back to the business task.  
Let's jump ahead a little to the Content sync platform architecture using Temporal!
![Content sync architecture](/images/content_sync_architecture.jpg)

Important notes here:
1. The content sources are **YouTube API** (for videos) and **News API** (for articles)
2. The main components of the platform (*Puller*, *Telegram Bot*) are 
implemented using Temporal Workflows and ZIO
3. The *Telegram Bot* is used to configure content sources
    - For instance, *YouTube* integration requires the user to Authenticate with *Google OAuth2* 
    - *News API* integration requires a list of topics the user is interested in 
4. *Content Pullers* fetch data from content sources and store it on the file system in Parquet format.
5. The content is then processed by a Spark Job (*Content Processor Job*)  
    - The Content Processor Job logic is out of the scope of these article series
    - The Job is launched via Temporal Workflow (*Content Processor Launcher*). It also retries the Job in case of failures
    - The Job performs some magic and stores recommended articles into a *Postgres Database*
6. The same *Telegram Bot* then uses stored recommendations and periodically pushes them into the *Telegram chat*


## What's next?
In the next article, you will dive deeper into the implementation details of each component.  
1. You will get started with Workflows and Activities using [ZIO Temporal](https://zio-temporal.vhonta.dev/)
2. You'll implement Workflows with Signal methods
3. You'll implement more complex business logic using Child Workflows
4. You'll dive deeper into Activities by using Activity Heartbeats
5. ...and much more!

Stay tuned for updates ✌️