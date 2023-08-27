---
title: "Temporal Workflows with ZIO: Introduction"
date: 2023-08-27T15:04:46+02:00
series: "Temporal Workflows with ZIO"
draft: false
tags: ["Temporal", "ZIO"]
---

## Introduction
Do you spend a lot of time making your applications resilient? Dealing with distributed state and locks? Migrating from sync to async communication? Adding retries, tracing?  

That's a usual programming routine that we, as engineers, must care about. On the other hand, it shifts our focus to techincal issues instead of the original bussiness problem.  

Can we change the status-quo? Is there any tools or instruments to help us struggle less and to be more productive?  

Meet Temporal — a distributed workflow management system for building invincible apps. It handles most technical problems, such as scaling, transactivity, managing state, and more. Temporal lets you focus on business needs and produce value quickly.

In this series of articles, I will show you how to solve *kinda* real business problems using the concept of workflows.

## About the business problem
We're going to develop a **Content syncrhonization platform** (lets call it the **content sync app**).  
**TL;DR** the source code is already available on [GitHub](https://github.com/vitaliihonta/zio-temporal-samples/tree/main/content-sync)

### User story
**As a regular person**, I struggle checking various sources of content (newsletters, videos on Youtube, etc). I wish there was an aggregator fetching *content I want* and making recommendations for me. For instance, a [Telegram Bot](https://telegram.org/faq#bots)

### Technical details
While it sounds pretty easy, the content sync app requires a thoughtful design *in case reliablity and scalability is a requirement*.  

The components of such a platform can be defined as follows:
- *Data ingestion* component responsible for *fetching the data*. For simplicity, lets call it **puller**
- *Data processing* component responsible for getting value out of data and for making recommendations for the end users. Lets call it **processor**
- *Frontend API* serving the data for users. In our case, it's gonna be the Telegram Bot interacting with the end user. Lets call it simply **telegram bot**.

Those components require:
- *Scheduler* to trigger the execution of compoments
  - Note: that's the requirement as many content sources don't support real-time updates streams
- *Syncrhonization mechamism* to run and supervise the content sync process end-to-end
- *Reliability* facilities in each component to guarantee proper error handling, retries and isolation (to localize the possible impact of errors, therefore avoiding global outages)
- *Storage layer* for raw data and processed data (can be the same or two separate storages)
- *User session store* for internal application-level data (for UI related functionality). 

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

### Content sync architecture with Temporal
![Content sync architecture](/images/content_sync_architecture.jpg)

