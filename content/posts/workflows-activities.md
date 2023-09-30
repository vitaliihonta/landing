---
title: "Workflows and Activities"
date: 2023-09-30T10:00:00+02:00
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

## Before we start
First, install *ZIO Temporal* locally via your favorite tool. In this example, I'm using *SBT*:
```scala
libraryDependencies ++= Seq(
  // Core
  "dev.vhonta" %% "zio-temporal-core" % "0.6.0",
  // Protobuf transport
  "dev.vhonta" %% "zio-temporal-protobuf" % "0.6.0",
  "dev.vhonta" %% "zio-temporal-protobuf" % "0.6.0" % "protobuf",
  // Testkit
  "dev.vhonta" %% "zio-temporal-testkit" % "0.6.0"
)
```


# Pulling content
You'll develop the Content Sync platform starting with the component that fetches videos from YouTube via its API.  
We must add a few more dependencies to implement it:
```scala
libraryDependencies ++= Seq(
  // ZIO Streams
  "dev.zio"  %% "zio-streams" % "2.0.18",
  // ZIO/Java NIO interop
  "dev.zio" %% "zio-nio" % "2.0.2",
  // Google SDKs
  "com.google.api-client" % "google-api-client" % "2.2.0",
  "com.google.apis" % "google-api-services-youtube" % "v3-rev20230502-2.0.0"
)
```

Before diving into Temporal, let's add the following `YoutubeClient` class to simplify further development. The implementation details are not neccessary for this article, so the methods are stubbed with testing data:
```scala
// A lot of YouTube Java API imports 
import com.google.api.services.youtube.model.{
  ResourceId,
  SearchResult,
  SearchResultSnippet,
  Subscription,
  SubscriptionContentDetails,
  SubscriptionSnippet
}
// ZIO imports
import zio._
import zio.stream._
// Other
import java.time.{LocalDateTime, Instant, ZoneOffset}

object YoutubeClient {
  val make: ULayer[YoutubeClient] =
    ZLayer.succeed(YoutubeClient())
}

// Dependencies doesn't matter ATM
case class YoutubeClient(/**/) {

  def listSubscriptions(accessToken: String): Stream[Throwable, Subscription] = {
    ZStream.range(1, 10).mapZIO(_ => makeRandomSubscription)
  }

  def channelVideos(
    accessToken: String,
    channelId:   String,
    minDate:     LocalDateTime,
    maxResults:  Long
  ): Stream[Throwable, SearchResult] = {
    ZStream.range(1, 10).mapZIO(_ => makeRandomVideo(channelId))
  }

  // Random data generators...
  private def makeRandomSubscription: UIO[Subscription] = {
    for {
      id         <- Random.nextUUID
      channelId  <- Random.nextUUID
      title      <- Random.nextString(10)
      itemsCount <- Random.nextIntBetween(10, 100)
    } yield {
      new Subscription()
        .setId(id.toString)
        .setSnippet(
          new SubscriptionSnippet()
            .setTitle(title)
            .setResourceId(new ResourceId().setChannelId(channelId.toString))
        )
        .setContentDetails(
          new SubscriptionContentDetails().setTotalItemCount(itemsCount)
        )
    }
  }

  private def makeRandomVideo(channelId: String): UIO[SearchResult] = {
    for {
      videoId <- Random.nextUUID
      title   <- Random.nextString(10)
    } yield {
      new SearchResult()
        .setId(new ResourceId().setVideoId(videoId.toString).setChannelId(channelId))
        .setSnippet(
          new SearchResultSnippet()
            .setTitle(title)
            .setDescription(s"Some description for video $videoId")
            .setPublishedAt(new com.google.api.client.util.DateTime(1668294000000L))
        )
    }
  }
}
``` 


## Activities
In *ZIO Temporal* (and Java SDK it's based on), the Activity Definition concists of two parts.  

The first one is **Activity Interface** - a *Scala trait* with a **@activityInterface** annotation. The Activity Interface can contain a many abstract methods as you need.  

### YouTube puller
Let's first start with the YouTube videos puller! 
The goal of an activity is to perform error-prone operations. In this case, it will be interaction with an external API (YouTube).  
TODO make a better intro.  
It's better to wrap activitie's input and output types into case classes. Let's introduce them:
```scala
// Input
case class FetchVideosParams(
    integrationId: Long,
    minDate: LocalDateTime,
    maxResults: Long,
)

// Output
case class FetchVideosResult(values: List[YoutubeSearchResult])

case class YoutubeSearchResult(
    videoId: String,
    title: String,
    description: Option[String],
    publishedAt: LocalDateTime
)
```

Here is the very basic Workflow Interface example:
```scala
import zio._
import zio.temporal._
import zio.temporal.activity._

@activityInterface
trait YoutubeActivities {
  def fetchVideos(params: FetchVideosParams): FetchVideosResult
}
```

The `fetchVideos` method must fetch videos of the top 5 user's subscriptions. For simplification, we pick top 5 based on the video publication rate.  
This is how the activity is implemented:
```scala
// Step 1: define an internal state as we're going to loop over the subscriptions
case class FetchVideosState(
    subscriptionsLeft: List[YoutubeSubscription],
    accumulator: FetchVideosResult
)

case class YoutubeSubscription(
    channelId: String,
    channelName: String
)

// Step 2: define the activity implementation
case class YoutubeActivitiesImpl(
  youtubeClient: YoutubeClient
)(implicit options: ZActivityRunOptions[Any])
  extends YoutubeActivities {

  // simple string for demonstration purposes
  private val youtubeAccessToken = "Hey, let me in"
  
  // We have to make pauses to avoid being rate-limited by YouTube API
  private val pollInterval = 5.seconds

  // Activity implementation
  override def fetchVideos(params: FetchVideosParams): FetchVideosResult = {
     ZActivity.run {
       for {
         _ <- ZIO.logInfo(s"Fetching videos integration=${params.integrationId}")
         // Populate the initial state for looping
         // by fetching the subscriptions
         initialState <- youtubeClient
                          .listSubscriptions(youtubeAccessToken)
                          .runCollect
                          .map { subscriptions =>
                            // Limit the number of subscriptions to reduce quota usage
                            val desiredSubscriptions = subscriptions
                              .sortBy(s =>
                                Option(s.getContentDetails.getTotalItemCount.toLong)
                                  .getOrElse(0L)
                              )(Ordering[Long].reverse)
                              .take(5)
                              .toList

                            FetchVideosState(
                              subscriptionsLeft = desiredSubscriptions.map { subscription =>
                                YoutubeSubscription(
                                  channelId = subscription.getSnippet.getResourceId.getChannelId,
                                  channelName = subscription.getSnippet.getTitle
                                )
                              },
                              accumulator = FetchVideosResult(values = Nil)
                            )
                          }
         result <- process(params)(initialState)
       } yield result
     }
  }

  // Loop over subscriptions
  private def process(params: FetchVideosParams)(state: FetchVideosState): Task[FetchVideosResult] = {
    // Finish if no more subscriptions left
    if (state.subscriptionsLeft.isEmpty) {
      ZIO.succeed(state.accumulator)
    } else {
      val subscription :: rest  = state.subscriptionsLeft

      val channelId = subscription.channelId

      for {
        _ <- ZIO.logInfo(s"Pulling channel=$channelId name=${subscription.channelName} (channels left: ${rest.size})")
        // Fetch videos via API
        videos <- youtubeClient
                    .channelVideos(youtubeAccessToken, channelId, params.minDate, params.maxResults)
                    .runCollect
        
        // Convert videos into our domain classes 
        convertedVideos = videos.map { result =>
                            YoutubeSearchResult(
                              videoId = result.getId.getVideoId,
                              title = result.getSnippet.getTitle,
                              description = Option(result.getSnippet.getDescription),
                              publishedAt = {
                                Instant
                                  .ofEpochMilli(result.getSnippet.getPublishedAt.getValue)
                                  .atOffset(ZoneOffset.UTC)
                                  .toLocalDateTime
                              }
                            )
                          }

        // Update the state for the next iteration
        updatedState = state.copy(
          subscriptionsLeft = rest,
          accumulator = state.accumulator.copy(values = state.accumulator.values ++ convertedVideos)
        )
        // Take a break to avoid being rate-limited by YouTube API
        _      <- ZIO.logInfo(s"Sleep for $pollInterval")
        _      <- ZIO.sleep(pollInterval)
        // Next iteration
        result <- process(params)(updatedState)
      } yield result
    }
  }
}
```

To be continued...

Finally, let's wrap the activity implementation into a `ZLayer` to use it later:
```scala
object YoutubeActivitiesImpl {
  val make: URLayer[YoutubeClient with ZActivityRunOptions[Any], YoutubeActivities] =
    ZLayer.fromFunction(YoutubeActivitiesImpl(_: YoutubeClient)(_: ZActivityRunOptions[Any]))
}
```

### Data lake activity
TODO introduce it

Input and output:
```scala
// Input
case class YoutubeVideosList(
    values: List[YoutubeSearchResult]
)

// Output
case class StoreVideosParameters(
    integrationId: Long,
    datalakeOutputDir: String
)
```

Interface:
```scala
@activityInterface
trait DatalakeActivities {
  def storeVideos(videos: YoutubeVideosList, params: StoreVideosParameters): Unit
}
```

TODO implement datalake activities

## Workflows
The Workflow Definition concists of two parts as well as the activity.  

The first one is **Workflow Interface** - a *Scala trait* with a **@workflowInterface** annotation. The Workflow Interface must contain a single abstract method with a **@workflowMethod** annotation.  

You start with defining Workflow input parameters and output results as case classes:
```scala
case class YoutubePullerParameters(
    integrationId: Long,
    minDate: LocalDateTime,
    maxResults: Long,
    datalakeOutputDir: String
)

case class PullingResult(
  processed: Long
)
```  

This is how you then define the Workflow Interface:
```scala
import zio._
import zio.temporal._
import zio.temporal.workflow._

@workflowInterface
trait YoutubePullWorkflow {
  @workflowMethod
  def pull(params: YoutubePullerParameters): PullingResult
}
```

The *Workflow Interface* is then used by the Client-side applications to schedule *Workflow Execution*.  
*Worker* must implement the interface to run scheduled *Workflow Executions*.  

### Workflow implementation
As mentioned above, the *Worker* must implement the interface to execute the Workflow.  
It is as simple as implementing a plain Scala trait:
```scala
class YoutubePullWorkflowImpl extends YoutubePullWorkflow {
  private val logger = ZWorkflow.makeLogger

  private val youtubeActivities = ZWorkflow.newActivityStub[YoutubeActivities](
    ZActivityOptions
      // it may take long time to process...
      .withStartToCloseTimeout(30.minutes)
      .withRetryOptions(
        ZRetryOptions.default
          .withMaximumAttempts(5)
          // bigger coefficient due for rate limiting
          .withBackoffCoefficient(3)
      )
  )

  private val datalakeActivities = ZWorkflow.newActivityStub[DatalakeActivities](
    ZActivityOptions
      .withStartToCloseTimeout(1.minute)
      .withRetryOptions(
        ZRetryOptions.default.withMaximumAttempts(5)
      )
  )

  override def pull(params: YoutubePullerParameters): PullingResult = {
    logger.info(
      s"Getting videos integrationId=${params.integrationId} minDate=${params.minDate} maxResults=${params.maxResults}"
    )
    val videos = ZActivityStub.execute(
      youtubeActivities.fetchVideos(
        FetchVideosParams(
          integrationId = params.integrationId,
          minDate = params.minDate,
          maxResults = params.maxResults
        )
      )
    )

    if (videos.values.isEmpty) {
      logger.info("No new videos found")
      PullingResult(0)
    } else {
      val videosCount = videos.values.size
      logger.info(s"Going to store $videosCount videos...")
      ZActivityStub.execute(
        datalakeActivities.storeVideos(
          videos = YoutubeVideosList(videos.values),
          params = StoreVideosParameters(
            integrationId = params.integrationId,
            datalakeOutputDir = params.datalakeOutputDir
          )
        )
      )
      PullingResult(videosCount)
    }
  }
}
```

### Scheduling Workflow Execution

An instance of **ZWorkflowClient** is used to interact with the Temporal Server, including workflow scheduling. It's required to provide a few parameters for the Workflow Execution:
1. **Task queue** (mandatory) the execution is routed to. Usually, different workflows are bound to different tasks queues, so that you can deploy and scale workers listening different tasks queues independently.
2. **Workflow ID** (mandatory) is the unique identifier for the current Workflow Execution. It is strongly recommended for the *Workflow ID* to be related to a business entity in your domain. The *Workflow ID* is the same among retries of the same *Workflow Execution*  
3. It's is also a good practice to specify other options, such as 
  1. Meaningful timeouts (such as **workflow run timeout** that limits the amount of time for a single workflow run attempt) 
  2. **Retry policies** (maximum number of timeouts, retry intervals, etc.)

Retry policies can be configured using `ZRetryOptions`. 
```scala
val retryOptions = ZRetryOptions.default
  .withMaximumAttempts(5) // maximum retry attempts
  .withInitialInterval(1.second) // initial backoff interval
  .withBackoffCoefficient(0.5) // exponential backoff coefficiant
  .withDoNotRetry(nameOf[IllegalArgumentException]) // do not retry certain errors 
// retryOptions: ZRetryOptions = ZRetryOptions(
//   maximumAttempts = Some(value = 5),
//   initialInterval = Some(value = PT1S),
//   backoffCoefficient = Some(value = 0.5),
//   maximumInterval = None,
//   doNotRetry = ArraySeq("java.lang.IllegalArgumentException"),
//   javaOptionsCustomization = zio.temporal.ZRetryOptions$$$Lambda$1914/0x0000000800a42040@48064a5a
// )
```

The configuration altoghether is specified using `ZWorkflowOptions`:
```scala
val workflowOptions = ZWorkflowOptions
  .withWorkflowId("<unique-workflow-id>")
  .withTaskQueue("echo-queue")
  .withWorkflowRunTimeout(10.second)
  .withRetryOptions(retryOptions)
// workflowOptions: ZWorkflowOptions = ZWorkflowOptions(
//   workflowId = "<unique-workflow-id>",
//   taskQueue = "echo-queue",
//   workflowIdReusePolicy = None,
//   workflowRunTimeout = Some(value = PT10S),
//   workflowExecutionTimeout = None,
//   workflowTaskTimeout = None,
//   retryOptions = Some(
//     value = ZRetryOptions(
//       maximumAttempts = Some(value = 5),
//       initialInterval = Some(value = PT1S),
//       backoffCoefficient = Some(value = 0.5),
//       maximumInterval = None,
//       doNotRetry = ArraySeq("java.lang.IllegalArgumentException"),
//       javaOptionsCustomization = zio.temporal.ZRetryOptions$$$Lambda$1914/0x0000000800a42040@48064a5a
//     )
//   ),
//   memo = Map(),
//   searchAttributes = None,
//   contextPropagators = List(),
//   disableEagerExecution = None,
//   javaOptionsCustomization = zio.temporal.workflow.ZWorkflowOptions$SetTaskQueue$$$Lambda$1916/0x0000000800a47040@6a2b6031
// )
``` 

You can specify other parameters when scheduling a *Workflow Execution*. For instance, there is a *workflow run timeout* .  

Here is an example of scheduling a *Workflow Execution*:

```scala
val createWorkflowStubZIO: URIO[ZWorkflowClient, ZWorkflowStub.Of[YoutubePullWorkflow]] = 
  ZIO.serviceWithZIO[ZWorkflowClient] { workflowClient =>
    workflowClient.newWorkflowStub[YoutubePullWorkflow](workflowOptions)
  }

val runWorkflowAndPrintResult: RIO[ZWorkflowClient, Unit] = 
  for {
    youtubePullWorkflow <- createWorkflowStubZIO

    pullResult <- ZWorkflowStub.execute(
      youtubePullWorkflow.pull(
        YoutubePullerParameters(
          integrationId = 1,
          minDate = LocalDateTime.of(2023, 1, 1, 0, 0),
          maxResults = 1000,
          datalakeOutputDir = "./datalake"
        )
      )
    )

    _ <- ZIO.logInfo("YouTube pull result=$pullResult")
  } yield ()
```

Few important notes:
1. `workflowClient.newWorkflowStub[YoutubePullWorkflow](<workflowOptions>)` returns an instance of `ZWorkflowStub.Of[YoutubePullWorkflow]`. *ZIO Temporal* provides you with a typed wrapper/stub to execute workflows.
2. Scheduling *Workflow Execution* requires network communication with the *Temporal Server*. Therefore, *Workflow Execution* arguments must be serialized an transfered over network
3. Executing the *Workflow* is just a method invocation, but under the hood it's a remote call. Therefore, it's required to wrap the workflow method invocation into `ZWorkflowStub.execute(...)` method. 
4. `ZWorkflowStub.execute` performs some compile-time checks for your code. For instance, it ensures you invoke the correct method (the one with `@workflowMethod` annotation). 
The method invocation is then transformed into a network call using low-level Java SDK primitives.
5. `ZWorkflowStub.execute` waits until the *Workflow* finishes:
  - In case of failure, it returns a failed `ZIO` with error details
  - In case of success, it returns the workflow result (a `PullingResult` in our case)
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

### Running the worker
TODO

To make this implementation running *Workflow Executions*, you must create and register a *Worker*. You must specify the *task queue* for the *Worker* and provide *Workflow* implementations there. An instance of **ZWorkerFactory** is used to create *Worker* and register *Workflow implementations*:

TODO register activities
```scala
import zio.temporal.worker._

val registerWorker = 
  ZWorkerFactory.newWorker("youtube-pulling-queue") @@
    ZWorker.addWorkflow[YoutubePullWorkflow].from(new YoutubePullWorkflowImpl) @@
    ZWorker.addActivityImplementationLayer(YoutubeActivitiesImpl.make)
// registerWorker: ZIO[ZWorkerFactory with YoutubeClient with ZActivityRunOptions[Any] with Scope, Nothing, ZWorker] = OnSuccess(
//   trace = "repl.MdocSession.MdocApp.registerWorker(workflows-activities.md:435)",
//   first = Sync(
//     trace = "repl.MdocSession.MdocApp.registerWorker(workflows-activities.md:435)",
//     eval = zio.ZIO$$Lambda$1942/0x0000000800a79c40@2e4262d2
//   ),
//   successK = zio.ZIO$$$Lambda$1919/0x0000000800a45840@546ca9da
// )
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
    ZWorkflowServiceStubsOptions.make,
    // Activities dependencies
    YoutubeClient.make,
    ZActivityRunOptions.default
  )
```


## Reference
- [Workflows overview](https://zio-temporal.vhonta.dev/docs/core/workflows)
- [Activities overview](https://zio-temporal.vhonta.dev/docs/core/activities)
- [ZIO Temporal Configuration](https://zio-temporal.vhonta.dev/docs/core/configuration)
- [ZIO Scope](https://zio.dev/reference/resource/scope/)
- [Youtube Java API](https://developers.google.com/youtube/v3/quickstart/java)