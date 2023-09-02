---
title: "Workflows and Activities"
date: 2023-09-02T12:46:30+02:00
description: "TBD"
date: 2023-09-01T10:00:00+02:00
series: "Temporal Workflows with ZIO"
draft: false
tags: ["Temporal", "ZIO"]
---

## Introduction
In the previous post, you've been introduced to [Temporal](https://temporal.io) and its main guilding blocks, [ZIO Temporal](https://zio-temporal.vhonta.dev) and the Content Sync Platform we're developing.

In this post, you will develop your own Workflows and Activities!  
Quick reminder about what they are:  
1. **Workflow** is the business process definition represented as code. It must be deterministic for the Temporal Server to guarantee resiliency.   
2. **Activity** is all the hard work and technical details. They perform error-prone operations (such as interactions with external systems and APIs), complex algorithms, etc. All non-deterministic code must be encapsulated into Activities

Let's get started!

## Workflow definition
Workflows are the basic building blocks in Temporal.
A Workflow Definition contains the actual business logic. It's determenistic, those free from any side effects.

```scala mdoc:silent
import zio._
import zio.temporal._
import zio.temporal.worker._
import zio.temporal.workflow._

@workflowInterface
trait EchoWorkflow {

  @workflowMethod
  def echo(str: String): String
}
```

## Reference
- [Workflow documentation](https://docs.temporal.io/workflows)