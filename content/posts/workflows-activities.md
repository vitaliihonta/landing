---
title: "Workflows and Activities"
date: 2023-09-06T10:00:00+02:00
description: "TODO add"
series: "Temporal Workflows with ZIO"
draft: false
tags: ["Temporal", "ZIO"]
---

## Introduction
In the previous post, you've been introduced to [Temporal](https://temporal.io) and its main guilding blocks, [ZIO Temporal](https://zio-temporal.vhonta.dev) and the Content Sync Platform we're developing.

In this post, you will develop your own Workflows and Activities!  
Quick reminder about what them:  
1. **Activity** is all the hard work and technical details. *Activities* perform error-prone operations (such as interactions with external systems and APIs), complex algorithms, etc.  
2. **Workflow** is the business process definition represented as code. 
*Workflows* implement the business logic using *Activities*. A *Workflow* can also spawn and supervise *Child Workflows*. 

To this guide, you must have a *Temporal Cluster* running. It's recommended to run a local instance using [Temporal CLI](https://docs.temporal.io/cli):

```shell
temporal server start-dev
```

The command spawns a local *Temporal* instance. It doesn't require any dependencies (such as a database instance). The Web UI is available on `http://localhost:8233/`. 

Let's get started!

## ZIO Temporal Basics
First, install *ZIO Temporal* locally via your favorite tool.
*SBT*:
```scala
// Core
libraryDependencies += "dev.vhonta" %% "zio-temporal-core" % "0.4.0"
// Protobuf transport
libraryDependencies += "dev.vhonta" %% "zio-temporal-protobuf" % "0.4.0"
// Testkit
libraryDependencies += "dev.vhonta" %% "zio-temporal-testkit" % "0.4.0"
```

*scala-cli*:
```scala
// Core
//> using lib "dev.vhonta::zio-temporal-core:0.4.0"
// Protobuf transport
//> using lib "dev.vhonta::zio-temporal-protobuf:0.4.0"
// Testkit
//> using lib "dev.vhonta::zio-temporal-testkit:0.4.0"
```

### Workflow definition
In *ZIO Temporal* (and Java SDK it's based on), the Workflow Definition concists of two parts.  

The first one is **Workflow Interface** - a *Scala trait* with a **@workflowInterface** annotation. The Workflow Interface must contain a single abstract method with a **@workflowMethod** annotation.  

Here is the very basic Workflow Interface example:
```scala
import zio._
import zio.temporal._
import zio.temporal.workflow._

@workflowInterface
trait EchoWorkflow {

  @workflowMethod
  def echo(str: String): String
}
```

The *Workflow Interface* is then used by the Client-side applications to schedule *Workflow Execution*.  
*Worker* must implement the interface to run scheduled *Workflow Executions*.  

### Scheduling Workflow Execution

An instance of **ZWorkflowClient** is used to interact with the Temporal Server, including workflow scheduling. It's required to provide a few mandatory parameters for the Workflow Execution:
1. **Task queue** the execution is routed to. Usually, different workflows are bound to different tasks queues, so that you can deploy and scale workers listening different tasks queues independently.
2. **Workflow ID** is the unique identifier for the current Workflow Execution. It is strongly recommended for the *Workflow ID* to be related to a business entity in your domain. The *Workflow ID* is the same among retries of the same *Workflow Execution* 

You can specify other parameters when scheduling a *Workflow Execution*. For instance, there is a *workflow run timeout* that limits the amount of time for a single workflow run attempt.  

Here is an example of scheduling a *Workflow Execution*:

```scala
val createWorkflowStubZIO: URIO[ZWorkflowClient, ZWorkflowStub.Of[EchoWorkflow]] = 
  ZIO.serviceWithZIO[ZWorkflowClient] { workflowClient =>
    workflowClient
      .newWorkflowStub[EchoWorkflow]
      .withTaskQueue("echo-queue")
      .withWorkflowId("<unique-workflow-id>")
      .withWorkflowRunTimeout(10.second)
      .build
  }

val runWorkflowAndPrintResult: RIO[ZWorkflowClient, Unit] = 
  for {
    echoWorkflowStub <- createWorkflowStubZIO

    echoedMessage <- ZWorkflowStub.execute(
      echoWorkflowStub.echo("Borsch")
    )

    _ <- ZIO.logInfo("Workflow execution result is $echoedMessage")
  } yield ()
```

Few important notes:
1. `workflowClient.newWorkflowStub[EchoWorkflow]...` returns an instance of `ZWorkflowStub.Of[EchoWorkflow]`. *ZIO Temporal* provides you with a typed wrapper/stub to execute workflows.
2. Scheduling *Workflow Execution* requires network communication with the *Temporal Server*. Therefore, *Workflow Execution* arguments must be serialized an transfered over network
3. Executing the *Workflow* is just a method invocation, but under the hood it's a remote call. Therefore, it's required to wrap the workflow method invocation into `ZWorkflowStub.execute(...)` method. 
4. `ZWorkflowStub.execute` performs some compile-time checks for your code. For instance, it ensures you invoke the correct method (the one with `@workflowMethod` annotation). 
The method invocation is then transformed into a network call using low-level Java SDK primitives.
5. `ZWorkflowStub.execute` waits until the *Workflow* finishes:
  - In case of failure, it returns a failed `ZIO` with error details
  - In case of success, it returns the workflow result (a `String` in our case)
6. If you don't want to wait for the *Workflow Execution* to finish, use `ZWorkflowStub.start` method. It schedules the *Workflow Execution*, but doesn't wait for it to complete.

Running the above code requires you to provide an instance of `ZWorkflowClient`.  
The assumption is that you have a single instance of the `ZWorkflowClient` that is shared trought the whole client application.  

*ZIO Temporal* lavarages *ZIO's* standard dependency injection and configuration capabilities for constructing library components such as `ZWorkflowClient`. Here is how you create it:

```scala
val clientProgram: Task[Unit] = 
  runWorkflowAndPrintResult.provide(
    // The client itself
    ZWorkflowClient.make,
    // Client's direct dependencies:
    // 1. Client configuration 
    ZWorkflowClientOptions.make,
    // 2. Workflow service stubs, responsible for all the RPC 
    ZWorkflowServiceStubs.make,
    ZWorkflowServiceStubsOptions.make
  )
```

### Worker implementation
As mentioned above, the *Worker* must implement the interface to execute the Workflow.  
It is as simple as implementing a plain Scala trait:
```scala
class EchoWorkflowImpl extends EchoWorkflow {
  override def echo(str: String): String = {
    println(s"Echo: $str")
    str
  }
}
```

To make this implementation running *Workflow Executions*, you must create and register a *Worker*. You must specify the *task queue* for the *Worker* and provide *Workflow* implementations there. An instance of **ZWorkerFactory** is used to create *Worker* and register *Workflow implementations*:

```scala
import zio.temporal.worker._

val registerWorker: URIO[ZWorkerFactory, ZWorker] = 
  ZWorkerFactory.newWorker("echo-queue") @@
    ZWorker.addWorkflow[EchoWorkflow].from(new EchoWorkflowImpl)
```
*Side note*: creating a *Worker* is an *effect*, so the *aspect-based* syntax (*@@*) is used to configure the *Worker*. It allows avoiding syntactic noise of monadic composition and accessing ZIO's environment.

You can now run the *Worker Program* with this *Worker* definition:

```scala
val workerProcess = 
  for {
    _  <- registerWorker
    _  <- ZWorkflowServiceStubs.setup()
    // blocks forever while the program is alive
    _  <- ZWorkerFactory.serve
  } yield ()

// provide dependencies
val workerProgram: RIO[Scope, Unit] =
  workerProcess.provideSome[Scope](
    // Worker factory itself
    ZWorkerFactory.make,
    // Worker factory configuration
    ZWorkerFactoryOptions.make,
    // It requires the workflow client
    ZWorkflowClient.make, 
    ZWorkflowClientOptions.make,
    // ...as well as the workflow service stubs
    ZWorkflowServiceStubs.make,
    ZWorkflowServiceStubsOptions.make
  )
```

### Activities definition
tbd


## Reference
- [Workflows overview](https://zio-temporal.vhonta.dev/docs/core/workflows)
- [Activities overview](https://zio-temporal.vhonta.dev/docs/core/activities)
- [ZIO Temporal Configuration](https://zio-temporal.vhonta.dev/docs/core/configuration)
- [ZIO Scope](https://zio.dev/reference/resource/scope/)