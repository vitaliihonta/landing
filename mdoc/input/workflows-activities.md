---
title: "Working with Workflows and Activities"
date: 2023-09-30T10:00:00+02:00
description: "Unlock the potential of orchestration using Temporal! In this blog post, we'll explore the essential components of Temporal: Workflows and Activities."
series: "Temporal Workflows with ZIO"
draft: false
tags: ["Temporal", "ZIO"]
---

## Introduction
In the previous post, you were introduced to [Temporal](https://temporal.io) and its main building blocks, [ZIO Temporal](https://zio-temporal.vhonta.dev), and the Content Sync Platform we're developing.

In this post, we'll develop your own Workflows and Activities!  
A quick reminder:  
1. **Activity** is all the hard work and technical details. *Activities* perform error-prone operations (such as interactions with external systems and APIs), complex algorithms, etc.  
2. **Workflow** is the business process definition represented as code. 
*Workflows* implement the business logic using *Activities*. A *Workflow* can also spawn and supervise *Child Workflows*. 

As a prerequisite, you must have a *Temporal Cluster* running. It's recommended to run a local instance using [Temporal CLI](https://docs.temporal.io/cli):

```shell
temporal server start-dev
```

The command spawns a local *Temporal* instance. It doesn't require any dependencies (such as a database instance). The Web UI is available on `http://localhost:8233/`. 

Let's get started!

## Before we start
You'll develop the Content Sync platform, starting with the component that fetches videos from YouTube via its API.  

**Disclaimer**: the original YouTube puller code is much more complicated as it implements more functionality (e.g., supporting multiple content sources in a generic way), and it manages the integration configuration per user. It is not necessary to dive into such details from the start, so we'll omit it.  

Let's focus on the Activities and Workflows basics. You'll learn how they help solve real problems!  

## YouTube Puller
During the tutorial, we'll implement the YouTube puller. It is non-trivial, so you have to install some dependencies.  
The final code is published in this [Github Gist](https://gist.github.com/vitaliihonta/3b1d6ea96422caef5ea11af03281ad77). The example uses [Scala CLI](https://scala-cli.virtuslab.org/) as it allows to run the example easily. You should either [install Scala CLI](https://scala-cli.virtuslab.org/install/) or adapt the example for your favorite build tool.  

The functionality you're implementing consists of multiple steps. All of them require [ZIO Temporal](https://zio-temporal.vhonta.dev/).  
Let's follow the implementation steps and collect the list of other dependencies:
1. Fetching data from YouTube. 
    - YouTube Java SDK is required to perform API requests.
    - ZIO Streams will help you to deal with data flows a lot
2. Converting data into a format common for all possible content sources.
    - Enumeratum is a must-have as you're working with Scala 2.13
3. Storing data in the file system.
    - In real life, it would be a distributed file system like HDFS or AWS S3. In the example, we're going to use a local file system.
    - A common data format used in data engineering is Parquet. However, for simplification, the puller will produce data serialized into JSON. Therefore, we're going to use ZIO JSON.
    - ZIO NIO helps reliably write data into files.

It is also worth it to add ZIO Logging and [ZIO Logging SLF4J Bridge](https://zio.dev/zio-logging/slf4j1-bridge/) as Temporal Java SDK uses SLF4J under the hood.  

Here is the final list of dependencies to add:
```scala
//> using scala 2.13
//> using dep dev.vhonta::zio-temporal-core:0.6.0
//> using dep dev.zio::zio:2.0.18
//> using dep dev.zio::zio-streams:2.0.18
//> using dep dev.zio::zio-nio:2.0.2
//> using dep dev.zio::zio-json:0.6.2
//> using dep dev.zio::zio-logging:2.1.14
//> using dep dev.zio::zio-logging-slf4j-bridge:2.1.14
//> using dep com.beachape::enumeratum:1.7.3
//> using dep com.google.api-client:google-api-client:2.2.0
//> using dep com.google.apis:google-api-services-youtube:v3-rev20230502-2.0.0
```

### Domain model
Let's begin with the domain model definition. You must define a unified schema for content coming from various sources (along with the serialization logic):
```scala mdoc
import enumeratum.{Enum, EnumEntry}
import java.time.LocalDateTime
import zio.json._

sealed trait ContentType extends EnumEntry
case object ContentType extends Enum[ContentType] {
  // The Content Sync currently supports only Text and Video
  case object Text  extends ContentType
  case object Video extends ContentType

  override val values = findValues

  // Define JSON serialization logic for enumeratum enums
  implicit val jsonCodec: JsonCodec[ContentType] = {
    JsonCodec(
      JsonEncoder.string.contramap[ContentType](_.entryName),
      JsonDecoder.string.mapOrFail(
        ContentType.withNameEither(_).left.map(_.getMessage)
      )
    )
  }
}


// The domain model for the Content we pull and process
@jsonMemberNames(SnakeCase)
case class ContentFeedItem(
  title:       String,
  description: Option[String],
  url:         String,
  publishedAt: LocalDateTime,
  contentType: ContentType)

// Define JSON serialization logic for the case class
object ContentFeedItem {
  implicit val jsonCodec: JsonCodec[ContentFeedItem] = 
    DeriveJsonCodec.gen[ContentFeedItem]
}
```

The *ContentFeedItem* class represents the data the Content Sync platform processes and provides the user with.  
Currently, the platform supports *Video* and *Text* content types. YouTube puller will produce *Video* content feed items.  

### YouTube client
The next step is to define a *YoutubeClient* class. That is meant to be a wrapper for YouTube Java APIs to simplify further development. However, the implementation details are not necessary for this article so the methods are stubbed with testing data:
```scala mdoc
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
    minDate:     LocalDateTime
  ): Stream[Throwable, SearchResult] = {
    ZStream.range(1, 10).mapZIO(_ => makeRandomVideo(channelId))
  }

  // Random subscription generator...
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

  // Random video generator...
  private def makeRandomVideo(channelId: String): UIO[SearchResult] = {
    for {
      videoId <- Random.nextUUID
      title   <- Random.nextString(10)
    } yield {
      new SearchResult()
        .setId(
          new ResourceId()
            .setVideoId(videoId.toString)
            .setChannelId(channelId)
        )
        .setSnippet(
          new SearchResultSnippet()
            .setTitle(title)
            .setDescription(s"Some description for video $videoId")
            .setPublishedAt(
              new com.google.api.client.util.DateTime(1668294000000L)
            )
        )
    }
  }
}
```

The data content doesn't really matter here. You should fill in only attributes that will be later used by the platform.

## Activities
In *ZIO Temporal* (and Java SDK it's based on), the Activity Definition consists of two parts.  

The first one is *Activity Interface* - a *Scala trait* with an *@activityInterface* annotation. The Activity Interface can contain as many abstract methods as you need. The activity interface is then used by Workflows.  

Activities perform error-prone operations. Therefore, we'll implement interaction with the *YouTube API* and the *file system* using Activities. 

### YouTube pulling activity
Our journey into activities starts with the YouTube video puller!  
It's a good practice to define activities' input and output as case classes.  
Let's introduce them:
```scala mdoc
// Input: how to fetch  the videos
case class FetchVideosParams(
    integrationId: Long,
    minDate: LocalDateTime
)

// Output: fetched videos
case class FetchVideosResult(values: List[YoutubeSearchResult])
// Video item
case class YoutubeSearchResult(
    videoId: String,
    title: String,
    description: Option[String],
    publishedAt: LocalDateTime
)
```

The next step is to define the activity interface:
```scala mdoc:silent
import zio._
import zio.temporal._
import zio.temporal.activity._

@activityInterface
trait YoutubeActivities {
  def fetchVideos(params: FetchVideosParams): FetchVideosResult
}
```

The *fetchVideos* method must fetch videos based on the user's subscriptions. For simplification, we pick the top 5 based on the video publication rate.  

Note that *fetchVideos* returns a pure value but not ZIO. It's necessary to define Activity Methods this way, otherwise, you won't be able to invoke Activities in Workflows.  

Once the interface is defined, the next step is to implement the activity logic:
```scala mdoc
// Step 1: define an internal state as we're going to use 
// while loop over the subscriptions
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
  // Pass dependencies (such as YouTube client) into the class constructor
  youtubeClient: YoutubeClient
  // This is required to run ZIO inside activities
)(implicit options: ZActivityRunOptions[Any])
  extends YoutubeActivities {

  // simple string for demonstration purposes
  private val youtubeAccessToken = "Hey, let me in"
  
  // We have to make pauses to avoid being rate-limited by YouTube API
  private val pollInterval = 5.seconds

  // Activity implementation
  override def fetchVideos(params: FetchVideosParams): FetchVideosResult = {
    // ZActivity.run "extracts" the value from ZIO
     ZActivity.run {
       for {
         _ <- ZIO.logInfo(s"Fetching videos integration=${params.integrationId}")
         // Fetching the subscriptions for the initial state
         subscriptions <- youtubeClient
                          .listSubscriptions(youtubeAccessToken)
                          .runCollect
         // Populate the initial state
         initialState = createInitialState(subscriptions)
         // Start the loop
         result <- process(params)(initialState)
       } yield result
     }
  }

  private def createInitialState(
    subscriptions: Chunk[Subscription]
  ): FetchVideosState = {
    // Limit the number of subscriptions to reduce quota usage
    val desiredSubscriptions = subscriptions
      .sortBy(s =>
        Option(
          s.getContentDetails.getTotalItemCount.toLong
        ).getOrElse(0L)
      )(Ordering[Long].reverse)
      // Get top 5
      .take(5)
      .toList

    FetchVideosState(
      subscriptionsLeft = desiredSubscriptions.map { 
        subscription =>
          YoutubeSubscription(
            channelId = subscription.getSnippet
              .getResourceId.getChannelId,
            channelName = subscription.getSnippet.getTitle
          )
      },
      accumulator = FetchVideosResult(values = Nil)
    )
  }

  // Loop over subscriptions
  private def process(params: FetchVideosParams)(
    state: FetchVideosState
  ): Task[FetchVideosResult] = {
    // Finish if no more subscriptions are left
    if (state.subscriptionsLeft.isEmpty) {
      ZIO.succeed(state.accumulator)
    } else {
      // Get the next subscription to process
      val subscription :: rest = state.subscriptionsLeft
      val channelId = subscription.channelId

      for {
        _ <- ZIO.logInfo(
          s"Pulling channel=$channelId name=${subscription.channelName} (channels left: ${rest.size})"
        )
        // Fetch videos via API
        videos <- youtubeClient
                    .channelVideos(
                      youtubeAccessToken, 
                      channelId, 
                      params.minDate
                    )
                    .runCollect
        
        // Convert videos into our domain classes 
        convertedVideos = videos.map { result =>
                            YoutubeSearchResult(
                              videoId = result.getId.getVideoId,
                              title = result.getSnippet.getTitle,
                              description = Option(
                                result.getSnippet.getDescription
                              ),
                              publishedAt = {
                                Instant
                                  .ofEpochMilli(
                                    result.getSnippet.getPublishedAt.getValue
                                  )
                                  .atOffset(ZoneOffset.UTC)
                                  .toLocalDateTime
                              }
                            )
                          }

        // Update the state for the next iteration
        updatedState = state.copy(
          subscriptionsLeft = rest,
          accumulator = state.accumulator.copy(
            values = state.accumulator.values ++ convertedVideos
          )
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

Important notes:  
- Use *ZActivity.run* method to run ZIO inside activities. It "extracts" the value (or the error) from ZIO
- In order to run ZIO, the *ZActivity.run* method requires an implicit *ZActivityRunOptions* available.
- Under the hood, *ZActivityRunOptions* uses the *ZIO Runtime* and *Temporal Java SDK* to complete the activity with ZIO's result

It is worth it to note that fetching all the information about videos may take some time. Temporal allows activities to save a checkpoint with the latest fetching progress. You don't use this API right now, but we'll come back to it in the next articles.  

Finally, let's wrap the activity implementation into a *ZLayer* to simplify the dependency injection later:
```scala mdoc
object YoutubeActivitiesImpl {
  val make: URLayer[YoutubeClient with ZActivityRunOptions[Any], YoutubeActivities] =
    ZLayer.fromFunction(
      YoutubeActivitiesImpl(_: YoutubeClient)(_: ZActivityRunOptions[Any])
    )
}
```

### Data Lake activity
The next step after pulling the data is storing it. The goal is to convert the raw data into our unified format and to store it in the file system as JSON lines files.
Let's define an activity interface called *DatalakeActivities* along with its input and output:
```scala mdoc
// Input: list of videos to store
case class YoutubeVideosList(
    values: List[YoutubeSearchResult]
)

// Input: where to store the data
case class StoreVideosParameters(
    integrationId: Long,
    datalakeOutputDir: String
)

// activity interface
@activityInterface
trait DatalakeActivities {
  def storeVideos(videos: YoutubeVideosList, params: StoreVideosParameters): Unit
}
```

The activity just stores the data and it doesn't return anything. In this case, you can use *Unit* as the return type.  

Let's implement the activity:
```scala mdoc:silent
// For configuration
import java.net.URI
// For file writes
import java.io.IOException
import zio._
import zio.stream._
import zio.json._
import zio.nio.file.Files
import zio.nio.file.Path

// List all the dependencies and configuration
case class DatalakeActivitiesImpl(
  youtubeBaseUri:   URI
  // ZActivityRunOptions to run ZIO
)(implicit options: ZActivityRunOptions[Any])
  extends DatalakeActivities {

  override def storeVideos(
    videos: YoutubeVideosList, 
    params: StoreVideosParameters
  ): Unit = {
    // Run ZIO code
    ZActivity.run {
      // To simplify writing, wrap the videos list into a ZStream
      val contentFeedItemsStream = ZStream
        .fromIterable(videos.values)
        .map { video =>
          ContentFeedItem(
            title = video.title,
            description = video.description,
            url = youtubeBaseUri.toString + video.videoId,
            publishedAt = video.publishedAt,
            contentType = ContentType.Video
          )
        }

      for {
        _ <- ZIO.logInfo("Storing videos")
        written <- writeStreamToJson(
                     contentFeedItemsStream = contentFeedItemsStream,
                     datalakeOutputDir = params.datalakeOutputDir,
                     integrationId = params.integrationId
                   )
        _ <- ZIO.logInfo(s"Written $written videos")
      } yield ()
    }
  }
  
  // Writes the data stream as JSON lines files
  private def writeStreamToJson(
    contentFeedItemsStream: UStream[ContentFeedItem],
    datalakeOutputDir:      String,
    integrationId:          Long
  ): IO[IOException, Long] = {

    // Writes a data chunk
    def writeChunk(now: LocalDateTime)(
      items: Chunk[ContentFeedItem]
    ): IO[IOException, Long] = {
      ZIO.scoped {
        for {
          uuid <- ZIO.randomWith(_.nextUUID)
          // Create pull directory if not exists
          dir = Path(datalakeOutputDir) / 
                   s"pulledDate=$now" / 
                   s"integration=$integrationId"
          _ <- Files.createDirectories(dir)

          // Write to a JSON lines file
          path = dir / s"pull-$uuid.jsonl"
          _ <- Files.writeLines(path, lines = items.map(_.toJson))
          // Return the number of objects written
        } yield items.size
      }
    }

    for {
      now <- ZIO.clockWith(_.localDateTime)
      written <- contentFeedItemsStream
                   // Write small chunks of data
                   .grouped(100)
                   .mapZIO(writeChunk(now))
                   // Calculate the total number of objects written
                   .runSum
    } yield written
  }
}

// For dependency injection
object DatalakeActivitiesImpl {
  val make: URLayer[ZActivityRunOptions[Any], DatalakeActivities] =
    // NOTE: it's better to read URI from a configuration file 
    // using ZIO Config capabilities
    ZLayer.fromFunction(
      DatalakeActivitiesImpl(new URI("https://www.youtube.com/watch?v="))(
        _: ZActivityRunOptions[Any]
      )
    )
}
```

There is nothing important to note here regarding ZIO Temporal. As you can see, it's possible to run any ZIO code in activities if you wrap it into *ZActivity.run* block. The activity creates directories, writes data into files, etc.  

## Workflows
The Workflow Definition consists of two main parts as well as the activity.  

The first one is *Workflow Interface* - a *Scala trait* with a *@workflowInterface* annotation. The Workflow Interface must contain a single abstract method with a *@workflowMethod* annotation.  

You will implement a *YoutubePullWorkflow* that uses the Activities you defined to fetch YouTube videos and store them in the file system.  

### Workflow Interface
You start with defining Workflow input parameters and output results as case classes:
```scala mdoc
// Input: what data to fetch and where to store
case class YoutubePullerParameters(
    integrationId: Long,
    minDate: LocalDateTime,
    datalakeOutputDir: String
)

// Output: how much data was processed
case class PullingResult(processed: Long)
```  

This is how you then define the Workflow Interface:
```scala mdoc:silent
import zio._
import zio.temporal._
import zio.temporal.workflow._

@workflowInterface
trait YoutubePullWorkflow {
  @workflowMethod
  def pull(params: YoutubePullerParameters): PullingResult
}
```

The *pull* workflow method will trigger the data fetching process and will (eventually) store the data.  

This *Workflow Interface* is then used by the Client-side applications to schedule *Workflow Execution*.  
The *Worker* must implement the interface to run scheduled *Workflow Executions*.  

### Workflow implementation
Implementing the workflow logic is as simple as implementing a plain Scala trait:

```scala mdoc:silent
// Just extend the workflow interface
class YoutubePullWorkflowImpl extends YoutubePullWorkflow {
  // Create a logger
  private val logger = ZWorkflow.makeLogger

  // Step 1: get the YoutubeActivities
  private val youtubeActivities: ZActivityStub.Of[YoutubeActivities] = 
    ZWorkflow.newActivityStub[YoutubeActivities](
      ZActivityOptions
        // it may take long time to process...
        .withStartToCloseTimeout(30.minutes)
        .withRetryOptions(
          ZRetryOptions.default
            .withMaximumAttempts(5)
            // bigger coefficient due to rate limiting on the YouTube side
            .withBackoffCoefficient(3)
        )
    )

  // Step 2: get the DatalakeActivities
  private val datalakeActivities = ZWorkflow.newActivityStub[DatalakeActivities](
    ZActivityOptions
      .withStartToCloseTimeout(1.minute)
      .withRetryOptions(
        ZRetryOptions.default.withMaximumAttempts(5)
      )
  )

  override def pull(params: YoutubePullerParameters): PullingResult = {
    logger.info(
      s"Getting videos integrationId=${params.integrationId} minDate=${params.minDate}"
    )
    // Step 3: execute YoutubeActivities.fetchVideos.
    // Note that the method invocation is wrapped into ZActivityStub.execute
    val videos = ZActivityStub.execute(
      youtubeActivities.fetchVideos(
        FetchVideosParams(
          integrationId = params.integrationId,
          minDate = params.minDate
        )
      )
    )

    if (videos.values.isEmpty) {
      // No need to produce empty files if there is no input data
      logger.info("No new videos found")
      PullingResult(0)
    } else {
      val videosCount = videos.values.size
      logger.info(s"Going to store $videosCount videos...")
      // Step 4: execute DatalakeActivities.storeVideos.
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

Important notes:
- *ZWorkflow.newActivityStub* provides you with a stub that communicates to the Temporal cluster to invoke activities
    - The method requires specifying the Activity Interface type and *ZActivityOptions*
- You must always wrap the activity method invocation into *ZActivityStub.execute* method.
    - It's because there is no direct method invocation but a remote call to the Temporal Server
    - The *ZActivityStub.Of[YoutubeActivities]* is a compile-time stub, so actual method invocations are only valid in compile-time
- Activity method invocation result is persisted by Temporal into the event store (e.g., database like Postgres etc.)
- Persisting the result allows the workflow to retry in case of any failures, starting from the closest successful activity invocation


### Scheduling Workflow Execution

An instance of *ZWorkflowClient* interacts with the Temporal Server, including workflow scheduling. It's required to provide a few parameters for the Workflow Execution:
1. **Task queue**  the execution is routed to. Usually, different workflows are bound to different task queues so that you can deploy and scale workers listening to different task queues independently. The parameter is **mandatory**.
2. **Workflow ID** is the unique identifier for the current Workflow Execution. The *Workflow ID* is strongly recommended to be related to a business entity in your domain. The *Workflow ID* is the same among retries of the same *Workflow Execution*. The parameter is **mandatory**.
3. It is also a good practice to specify other options, such as 
    - Meaningful timeouts (like  **workflow run timeout** that limits the amount of time for a single workflow run attempt).
    - **Retry policies** (maximum number of timeouts, retry intervals, etc.)

Retry policies are configured using *ZRetryOptions*:
```scala mdoc:silent
val retryOptions = ZRetryOptions.default
  // maximum retry attempts
  .withMaximumAttempts(5)
  // initial backoff interval
  .withInitialInterval(1.second)
  // exponential backoff coefficiant
  .withBackoffCoefficient(1.2)
  // do not retry certain errors 
  .withDoNotRetry(nameOf[IllegalArgumentException])
```

The configuration altogether is specified using *ZWorkflowOptions*. Besides the aforementioned parameters, you can specify various timeouts (such as *workflow run timeout*), etc.  
```scala mdoc
val workflowOptions = ZWorkflowOptions
  .withWorkflowId("youtube/23c86a79-0fc8-4ac7-b2bf-cc2974103a05")
  .withTaskQueue("youtube-pulling-queue")
  .withWorkflowRunTimeout(20.minutes)
  .withRetryOptions(retryOptions)
``` 

Here is an example of scheduling a *Workflow Execution*:

```scala mdoc:silent
val startWorkflow: RIO[ZWorkflowClient, Unit] = 
  ZIO.serviceWithZIO[ZWorkflowClient] { workflowClient =>
    for {
      // Step 1: create a workflow stub
      youtubePullWorkflow <- workflowClient
                               .newWorkflowStub[YoutubePullWorkflow](
                                  workflowOptions
                               )
      // Step 2: start the workflow
      _ <- ZWorkflowStub.start(
        youtubePullWorkflow.pull(
          // Provide input parameters
          YoutubePullerParameters(
            integrationId = 1,
            minDate = LocalDateTime.of(2023, 1, 1, 0, 0),
            datalakeOutputDir = "./datalake"
          )
        )
      )

      _ <- ZIO.logInfo("YouTube pull result workflow started!")
    } yield ()
  }
```

A few important notes:
1. *workflowClient.newWorkflowStub[YoutubePullWorkflow]\(workflowOptions\)* returns an instance of *ZWorkflowStub.Of[YoutubePullWorkflow]*. *ZIO Temporal* provides you with a typed wrapper/stub to execute workflows.
    - Scheduling *Workflow Execution* requires network communication with the *Temporal Server*. Therefore, *Workflow Execution* arguments must be serialized and transferred over the network
    - Therefore, it's required to wrap the workflow method invocation into the *ZWorkflowStub.start* method. 
    - *ZWorkflowStub.start* checks your code at compile-time. For instance, it ensures you invoke the correct method (the one with *@workflowMethod* annotation). The method invocation is then transformed into a remote call using low-level Java SDK primitives.
2. *ZWorkflowStub.start* doesn't wait for the *Workflow* to be executed:
    - It returns immediately once the Temporal Server schedules this workflow execution
    - If you want to wait for the *Workflow Execution* to finish, use *ZWorkflowStub.execute* method. It schedules the *Workflow Execution* and waits until it's picked up by a worker and executed. The method returns the workflow result in case of success (a *PullingResult* in our case) and the error details in case of failure.

Running the above code requires you to provide an instance of *ZWorkflowClient*.  
The assumption is that you have a single instance of the *ZWorkflowClient* that is shared through the whole client application.  

*ZIO Temporal* leverages *ZIO's* standard dependency injection and configuration capabilities for constructing library components such as *ZWorkflowClient*. Here is how you create it:

```scala mdoc:silent
val clientProgram: Task[Unit] = 
  startWorkflow.provide(
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
The client program you defined allows scheduling YouTube pulling workflow execution. The next step is to set up a Worker process that will execute the workflow logic.  

To make this implementation run *Workflow Executions*, you must create and register a *ZWorker*. You must specify the *task queue* for the *ZWorker* and provide *Workflow* and *Activity* implementations there. An instance of *ZWorkerFactory* is used to create *ZWorkers* and register *Workflow implementations*:

```scala mdoc:silent
import zio.temporal.worker._

// Note that activities' dependencies are propagated
val registerWorker: URIO[ZWorkerFactory with YoutubeClient with ZActivityRunOptions[Any] with Scope, ZWorker] = 
  ZWorkerFactory.newWorker("youtube-pulling-queue") @@
    // Register workflow
    ZWorker.addWorkflow[YoutubePullWorkflow].from(new YoutubePullWorkflowImpl) @@
    // Register activity implementations
    ZWorker.addActivityImplementationLayer(YoutubeActivitiesImpl.make) @@
    ZWorker.addActivityImplementationLayer(DatalakeActivitiesImpl.make)
```
*Side note*: creating a *ZWorker* is an *effect*, so the *aspect-based* syntax (*@@*) is used to configure the *ZWorker*. It allows for avoiding the syntactic noise of monadic composition and accessing ZIO's environment.

You can now run the *Worker Program* with this *ZWorker* definition:

```scala mdoc:silent
val workerProcess = 
  for {
    _  <- registerWorker
    // Setup the internal transport
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
That's it! Once you run the worker program, it will start picking up workflows you previously scheduled for execution.  

## Temporal UI
After you schedule workflow execution and start the worker process, go ahead to Temporal UI on `http://localhost:8233`.  

Once you open it, you should see a list of workflow executions created on the Temporal Server:  

![Workflows listing](/images/workflows-and-activities/workflows_list.png)

You can navigate to workflow details by clicking on the workflow run. On this page, you should see the information about the workflow, such as *Workflow ID*, *Task Queue*, *Workflow Type*, the input parameters, and the workflow result (or error if it failed).  

![Workflow details](/images/workflows-and-activities/workflow_details.png)

Scroll down to see the *Workflow Execution History*. It contains a detailed log of activities invocation, activity input parameters, and activity results as well. The history also contains the number of retries performed (if any) and error stack traces if something fails.  

![Workflow history](/images/workflows-and-activities/workflow_history.png)

## Homework
I suggest you experiment with the example to learn Temporal basics better 🙃
Here is what you can try:
- Define your own activity, providing additional functionality, and use it in the *YoutubePullerWorkflow*💡
- Introduce random errors in the activities code. Take a look at how Temporal performs retries and handles them 🔄
- Kill the worker process in the middle of the Workflow Execution. Observe how the Workflow Execution is later resumed once you start a new worker 💪

I hope you enjoy it!

## What's next
In the next post in the series, you'll get familiar with other Workflow building parts, such as *Query methods*, *Signal methods*, etc.  
They'll allow you to implement a Workflow responsible for user interactions.  
See you in the next part! 

## Reference
- [Workflows overview](https://zio-temporal.vhonta.dev/docs/core/workflows)
- [Activities overview](https://zio-temporal.vhonta.dev/docs/core/activities)
- [Workers overview](https://zio-temporal.vhonta.dev/docs/core/workers)
- [ZIO Temporal Configuration](https://zio-temporal.vhonta.dev/docs/core/configuration)
- [ZIO Streams Documentation](https://zio.dev/reference/stream/)
- [ZIO Scope](https://zio.dev/reference/resource/scope/)
- [ZIO JSON Documentation](https://zio.dev/zio-json/)
- [ZIO NIO Documentation](https://zio.dev/zio-nio/)
- [Youtube Java API](https://developers.google.com/youtube/v3/quickstart/java)