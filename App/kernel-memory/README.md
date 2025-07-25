# Kernel Memory

[![License: MIT](https://img.shields.io/github/license/microsoft/kernel-memory)](https://github.com/microsoft/kernel-memory/blob/main/LICENSE)
[![Discord](https://img.shields.io/discord/1063152441819942922?label=Discord&logo=discord&logoColor=white&color=d82679)](https://aka.ms/KMdiscord)

This repository presents best practices and a reference architecture for memory in specific
AI and LLMs application scenarios. Please note that **the provided code serves as a
demonstration** and is **not an officially supported** Microsoft offering.

**Kernel Memory** (KM) is a **multi-modal [AI Service](service/Service/README.md)**
specialized in the efficient indexing of datasets through custom continuous data
hybrid pipelines, with support for
**[Retrieval Augmented Generation](https://en.wikipedia.org/wiki/Prompt_engineering#Retrieval-augmented_generation)** (RAG),
synthetic memory, prompt engineering, and custom semantic memory processing.

KM is available as a **Web Service**,
as a **[Docker container](https://hub.docker.com/r/kernelmemory/service)**,
a **[Plugin](https://learn.microsoft.com/copilot/plugins/overview)**
for ChatGPT/Copilot/Semantic Kernel, and as a .NET library for embedded applications.

![image](https://github.com/microsoft/kernel-memory/assets/371009/31894afa-d19e-4e9b-8d0f-cb889bf5c77f)

Utilizing advanced embeddings and LLMs, the system enables Natural Language
querying for obtaining answers from the indexed data, complete with citations
and links to the original sources.

![image](https://github.com/microsoft/kernel-memory/assets/371009/c5f0f6c3-814f-45bf-b055-063f23ed80ea)

Designed for seamless integration as a Plugin with
[Semantic Kernel](https://github.com/microsoft/semantic-kernel), Microsoft
Copilot and ChatGPT, Kernel Memory enhances data-driven features in applications
built for most popular AI platforms.

# Synchronous Memory API (aka "serverless")

Kernel Memory works and scales at best when running as an asynchronous **Web Service**, allowing to
ingest thousands of documents and information without blocking your app.

However, Kernel Memory can also run in serverless mode, embedding `MemoryServerless`
class instance in .NET backend/console/desktop apps in synchronous mode. This approach
works as well as in ASP.NET Web APIs and Azure Functions. Each request is processed
immediately, although calling clients are responsible for handling transient errors.

![image](https://github.com/microsoft/kernel-memory/blob/main/docs/infra-sync.png?raw=true)

> ### Importing documents into your Kernel Memory can be as simple as this:
>
> ```csharp
> var memory = new KernelMemoryBuilder()
>     .WithOpenAIDefaults(Environment.GetEnvironmentVariable("OPENAI_API_KEY"))
>     .Build<MemoryServerless>();
>
> // Import a file
> await memory.ImportDocumentAsync("meeting-transcript.docx", tags: new() { { "user", "Blake" } });
>
> // Import multiple files and apply multiple tags
> await memory.ImportDocumentAsync(new Document("file001")
>     .AddFile("business-plan.docx")
>     .AddFile("project-timeline.pdf")
>     .AddTag("user", "Blake")
>     .AddTag("collection", "business")
>     .AddTag("collection", "plans")
>     .AddTag("fiscalYear", "2023"));
> ```

> ### Asking questions:
>
> ```csharp
> var answer1 = await memory.AskAsync("How many people attended the meeting?");
>
> var answer2 = await memory.AskAsync("what's the project timeline?", filter: new MemoryFilter().ByTag("user", "Blake"));
> ```

The example leverages the default documents ingestion pipeline:

1. Extract text: recognize the file format and extract the information
2. Partition the text in small chunks, to optimize search
3. Extract embedding using an LLM embedding generator
4. Save embedding into a vector index such as
   [Azure AI Search](https://learn.microsoft.com/azure/search/vector-search-overview),
   [Qdrant](https://qdrant.tech/) or other DBs.

In the example, memories are organized by users using tags, safeguarding private information.
Furthermore, memories can be categorized and structured using **tags**, enabling efficient
search and retrieval through faceted navigation.

> ### Data lineage, citations, referencing sources:
>
> All memories and answers are fully correlated to the data provided. When
> producing an answer, Kernel Memory includes all the information needed
> to verify its accuracy:
>
> ```csharp
> await memory.ImportFileAsync("NASA-news.pdf");
>
> var answer = await memory.AskAsync("Any news from NASA about Orion?");
>
> Console.WriteLine(answer.Result + "/n");
>
> foreach (var x in answer.RelevantSources)
> {
>     Console.WriteLine($"  * {x.SourceName} -- {x.Partitions.First().LastUpdate:D}");
> }
> ```
>
> > Yes, there is news from NASA about the Orion spacecraft. NASA has invited the
> > media to see a new test version [......] For more information about the Artemis program,
> > you can visit the NASA website.
> >
> > - **NASA-news.pdf -- Tuesday, August 1, 2023**

# Memory as a Service - Asynchronous API

Depending on your scenarios, you might want to run all the code **locally
inside your process, or remotely through an asynchronous and scalable service.**

![image](https://github.com/microsoft/kernel-memory/blob/main/docs/infra-async.png?raw=true)

If you're importing small files, and need only C# and can block
the process during the import, local-in-process execution can be fine, using
the **MemoryServerless** seen above.

However, if you are in one of these scenarios:

- I'd just like a web service to import data and send queries to answer
- My app is written in **TypeScript, Java, Rust, or some other language**
- I'm importing **big documents that can require minutes to process**, and
  I don't want to block the user interface
- I need memory import to **run independently, supporting failures and retry
  logic**
- I want to define **custom pipelines mixing multiple languages**
  like Python, TypeScript, etc

then you can deploy Kernel Memory as a backend service, plugging in the
default handlers, or your custom Python/TypeScript/Java/etc. handlers,
and leveraging the asynchronous non-blocking memory encoding process,
sending documents and asking questions using the **MemoryWebClient**.

[Here](service/Service/README.md) you can find a complete set of instruction
about [how to run the Kernel Memory service](service/Service/README.md).

# Kernel Memory (KM) and SK Semantic Memory (SM)

**Kernel Memory (KM) is a service** built on the feedback received and lessons learned
from developing Semantic Kernel (SK) and Semantic Memory (SM). It provides several
features that would otherwise have to be developed manually, such as storing files,
extracting text from files, providing a framework to secure users' data, etc.
The KM codebase is entirely in .NET, which eliminates the need to write and maintain
features in multiple languages. As a service, **KM can be used from any language, tool,
or platform, e.g. browser extensions and ChatGPT assistants.**

**Semantic Memory (SM) is a library for C#, Python, and Java** that wraps direct calls
to databases and supports vector search. It was developed as part of the Semantic
Kernel (SK) project and serves as the first public iteration of long-term memory.
The core library is maintained in three languages, while the list of supported
storage engines (known as "connectors") varies across languages.

Here's comparison table:

| Feature                                 | Kernel Memory                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Semantic Memory                                                                                              |
| --------------------------------------- |------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------| ------------------------------------------------------------------------------------------------------------ |
| Data formats                            | Web pages, PDF, Images, Word, PowerPoint, Excel, Markdown, Text, JSON, HTML                                                                                                                                                                                                                                                                                                                                                                                                                          | Text only                                                                                                    |
| Search                                  | Cosine similarity, Hybrid search with filters (AND/OR conditions)                                                                                                                                                                                                                                                                                                                                                                                                                                    | Cosine similarity                                                                                            |
| Language support                        | Any language, command line tools, browser extensions, low-code/no-code apps, chatbots, assistants, etc.                                                                                                                                                                                                                                                                                                                                                                                              | C#, Python, Java                                                                                             |
| Storage engines                         | [Azure AI Search](https://azure.microsoft.com/products/ai-services/ai-search), [Elasticsearch](https://www.nuget.org/packages/FreeMindLabs.KernelMemory.Elasticsearch), [MongoDB Atlas](https://www.mongodb.com/atlas/database), [Postgres+pgvector](https://github.com/microsoft/kernel-memory/extensions/postgres), [Qdrant](https://qdrant.tech), [Redis](https://redis.io), [SQL Server](https://www.nuget.org/packages/Microsoft.KernelMemory.MemoryDb.SQLServer/), In memory KNN, On disk KNN. | Azure AI Search, Chroma, DuckDB, Kusto, Milvus, MongoDB, Pinecone, Postgres, Qdrant, Redis, SQLite, Weaviate |
| File storage                            | Disk, [Azure Blobs](https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction), [AWS S3](https://aws.amazon.com/s3), [MongoDB Atlas](https://www.mongodb.com/atlas/database), In memory (volatile)                                                                                                                                                                                                                                                                                  | -                                                                                                            |
| RAG                                     | Yes, with sources lookup                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | -                                                                                                            |
| Summarization                           | Yes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | -                                                                                                            |
| OCR                                     | Yes via [Azure Document Intelligence](https://azure.microsoft.com/products/ai-services/ai-document-intelligence)                                                                                                                                                                                                                                                                                                                                                                                     | -                                                                                                            |
| Security Filters                        | Yes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | -                                                                                                            |
| Large document ingestion                | Yes, including async processing using queues ([Azure Queues](https://learn.microsoft.com/azure/storage/queues/storage-queues-introduction), [RabbitMQ](https://www.rabbitmq.com), File based or In memory queues)                                                                                                                                                                                                                                                                                    | -                                                                                                            |
| Document storage                        | Yes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | -                                                                                                            |
| Custom storage schema                   | some DBs                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | -                                                                                                            |
| Vector DBs with internal embedding      | Yes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | -                                                                                                            |
| Concurrent write to multiple vector DBs | Yes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | -                                                                                                            |
| LLMs                                    | [Azure OpenAI](https://learn.microsoft.com/azure/ai-services/openai/concepts/models), [OpenAI](https://platform.openai.com/docs/models), [Anthropic](https://www.anthropic.com), [LLamaSharp](https://github.com/SciSharp/LLamaSharp) via [llama.cpp](https://github.com/ggerganov/llama.cpp), [LM Studio](https://lmstudio.ai/), Semantic Kernel connectors                                                                                                                                         | Azure OpenAI, OpenAI, Gemini, Hugging Face, ONNX, custom ones, etc.                                          |
| LLMs with dedicated tokenization        | Yes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | No                                                                                                           |
| Cloud deployment                        | Yes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | -                                                                                                            |
| Web service with OpenAPI                | Yes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | -                                                                                                            |

## Quick test using the Docker image

If you want to give the service a quick test, use the following command
to **start the Kernel Memory Service** using OpenAI:

```shell
docker run -e OPENAI_API_KEY="..." -it --rm -p 9001:9001 kernelmemory/service
```

If you prefer using custom settings and services such as Azure OpenAI, Azure
Document Intelligence, etc., you should create an `appsettings.Development.json`
file overriding the default values set in `appsettings.json`, or using the
configuration wizard included:

    cd service/Service
    dotnet run setup

Then run this command to start the [Docker image](https://hub.docker.com/r/kernelmemory/service)
with the configuration just created:

on Windows:

    docker run --volume .\appsettings.Development.json:/app/appsettings.Production.json -it --rm -p 9001:9001 kernelmemory/service

on macOS/Linux:

    docker run --volume ./appsettings.Development.json:/app/appsettings.Production.json -it --rm -p 9001:9001 kernelmemory/service

# Import files using KM web service and `MemoryWebClient`

> ```csharp
> #reference clients/WebClient/WebClient.csproj
>
> var memory = new MemoryWebClient("http://127.0.0.1:9001"); // <== URL where the web service is running
>
> // Import a file (default user)
> await memory.ImportDocumentAsync("meeting-transcript.docx");
>
> // Import a file specifying a Document ID, User and Tags
> await memory.ImportDocumentAsync("business-plan.docx",
>     new DocumentDetails("user@some.email", "file001")
>         .AddTag("collection", "business")
>         .AddTag("collection", "plans")
>         .AddTag("fiscalYear", "2023"));
> ```

# Get answers via the web service

> ```
> curl http://127.0.0.1:9001/ask -d'{"query":"Any news from NASA about Orion?"}' -H 'Content-Type: application/json'
> ```
>
> ```json
> {
>   "Query": "Any news from NASA about Orion?",
>   "Text": "Yes, there is news from NASA about the Orion spacecraft. NASA has invited the media to see a new test version [......] For more information about the Artemis program, you can visit the NASA website.",
>   "RelevantSources": [
>     {
>       "Link": "...",
>       "SourceContentType": "application/pdf",
>       "SourceName": "file5-NASA-news.pdf",
>       "Partitions": [
>         {
>           "Text": "Skip to main content\nJul 28, 2023\nMEDIA ADVISORY M23-095\nNASA Invites Media to See Recovery Craft for\nArtemis Moon Mission\n(/sites/default/ﬁles/thumbnails/image/ksc-20230725-ph-fmx01_0003orig.jpg)\nAboard the [......] to Mars (/topics/moon-to-\nmars/),Orion Spacecraft (/exploration/systems/orion/index.html)\nNASA Invites Media to See Recovery Craft for Artemis Moon Miss... https://www.nasa.gov/press-release/nasa-invites-media-to-see-recov...\n2 of 3 7/28/23, 4:51 PM",
>           "Relevance": 0.8430657,
>           "SizeInTokens": 863,
>           "LastUpdate": "2023-08-01T08:15:02-07:00"
>         }
>       ]
>     }
>   ]
> }
> ```

You can find a [full example here](https://github.com/microsoft/kernel-memory/blob/main/examples/001-dotnet-WebClient/README.md).

# Custom memory ingestion pipelines

On the other hand, if you need a custom data pipeline, you can also
customize the steps, which will be handled by your custom business logic:

```csharp
// Memory setup, e.g. how to calculate and where to store embeddings
var memoryBuilder = new KernelMemoryBuilder()
    .WithoutDefaultHandlers()
    .WithOpenAIDefaults(Environment.GetEnvironmentVariable("OPENAI_API_KEY"));

var memory = memoryBuilder.Build();

// Plug in custom .NET handlers
memory.Orchestrator.AddHandler<MyHandler1>("step1");
memory.Orchestrator.AddHandler<MyHandler2>("step2");
memory.Orchestrator.AddHandler<MyHandler3>("step3");

// Use the custom handlers with the memory object
await memory.ImportDocumentAsync(
    new Document("mytest001")
        .AddFile("file1.docx")
        .AddFile("file2.pdf"),
    steps: new[] { "step1", "step2", "step3" });
```

# Web API specs with OpenAI swagger

The API schema is available at http://127.0.0.1:9001/swagger/index.html when
running the service locally with OpenAPI enabled.

# Examples and Tools

## Examples

1. [Collection of Jupyter notebooks with various scenarios](https://github.com/microsoft/kernel-memory/tree/main/examples/000-notebooks)
2. [Using Kernel Memory web service to upload documents and answer questions](https://github.com/microsoft/kernel-memory/tree/main/examples/001-dotnet-WebClient)
3. [Importing files and asking question without running the service (serverless mode)](https://github.com/microsoft/kernel-memory/tree/main/examples/002-dotnet-Serverless)
4. [Using KM Plugin for Semantic Kernel](https://github.com/microsoft/kernel-memory/tree/main/examples/003-dotnet-SemanticKernel-plugin)
5. [Processing files with custom logic (custom handlers) in serverless mode](https://github.com/microsoft/kernel-memory/tree/main/examples/004-dotnet-serverless-custom-pipeline)
6. [Processing files with custom logic (custom handlers) in asynchronous mode](https://github.com/microsoft/kernel-memory/tree/main/examples/005-dotnet-async-memory-custom-pipeline)
7. [Upload files and ask questions from command line using curl](https://github.com/microsoft/kernel-memory/tree/main/examples/006-curl-calling-webservice)
8. [Customizing RAG and summarization prompts](https://github.com/microsoft/kernel-memory/tree/main/examples/101-dotnet-custom-Prompts)
9. [Custom partitioning/text chunking options](https://github.com/microsoft/kernel-memory/tree/main/examples/102-dotnet-custom-partitioning-options)
10. [Using a custom embedding/vector generator](https://github.com/microsoft/kernel-memory/tree/main/examples/103-dotnet-custom-EmbeddingGenerator)
11. [Using custom LLMs](https://github.com/microsoft/kernel-memory/tree/main/examples/104-dotnet-custom-LLM)
12. [Using LLama](https://github.com/microsoft/kernel-memory/tree/main/examples/105-dotnet-serverless-llamasharp)
13. [Summarizing documents, using synthetic memories](https://github.com/microsoft/kernel-memory/tree/main/examples/106-dotnet-retrieve-synthetics)
14. [Using Semantic Kernel LLM connectors](https://github.com/microsoft/kernel-memory/tree/main/examples/107-dotnet-SemanticKernel-TextCompletion)
15. [Using custom content decoders](https://github.com/microsoft/kernel-memory/tree/main/examples/108-dotnet-custom-content-decoders)
16. [Using a custom web scraper to fetch web pages](https://github.com/microsoft/kernel-memory/tree/main/examples/109-dotnet-custom-webscraper)
17. [Generating answers with Anthropic LLMs](https://github.com/microsoft/kernel-memory/tree/main/examples/110-dotnet-anthropic)
18. [Hybrid Search with Azure AI Search](https://github.com/microsoft/kernel-memory/tree/main/examples/111-dotnet-azure-ai-hybrid-search)
19. [Writing and using a custom ingestion handler](https://github.com/microsoft/kernel-memory/tree/main/examples/201-dotnet-serverless-custom-handler)
20. [Running a single asynchronous pipeline handler as a standalone service](https://github.com/microsoft/kernel-memory/tree/main/examples/202-dotnet-custom-handler-as-a-service)
21. [Test project using KM package from nuget.org](https://github.com/microsoft/kernel-memory/tree/main/examples/203-dotnet-using-KM-nuget)
22. [Integrating Memory with ASP.NET applications and controllers](https://github.com/microsoft/kernel-memory/tree/main/examples/204-dotnet-ASP.NET-MVC-integration)
23. [Sample code showing how to extract text from files](https://github.com/microsoft/kernel-memory/tree/main/examples/205-dotnet-extract-text-from-docs)
24. [.NET configuration and logging](https://github.com/microsoft/kernel-memory/tree/main/examples/206-dotnet-configuration-and-logging)
25. [Expanding chunks retrieving adjacent partitions](https://github.com/microsoft/kernel-memory/tree/main/examples/207-dotnet-expanding-chunks-on-retrieval)
26. [Using local models via LM Studio](https://github.com/microsoft/kernel-memory/tree/main/examples/208-dotnet-lmstudio)
27. [Using Context Parameters to customize RAG prompt during a request](https://github.com/microsoft/kernel-memory/tree/main/examples/209-dotnet-using-context-overrides)
28. [Creating a Memory instance without KernelMemoryBuilder](https://github.com/microsoft/kernel-memory/tree/main/examples/210-KM-without-builder)

## Tools

1. [.NET appsettings.json generator](tools/InteractiveSetup)
2. [Curl script to upload files](tools/upload-file.sh)
3. [Curl script to ask questions](tools/ask.sh)
4. [Curl script to search documents](tools/search.sh)
5. [Script to start Qdrant for development tasks](tools/run-qdrant.sh)
6. [Script to start Elasticsearch for development tasks](tools/run-elasticsearch.sh)
7. [Script to start MS SQL Server for development tasks](tools/run-mssql.sh)
8. [Script to start Redis for development tasks](tools/run-redis.sh)
9. [Script to start RabbitMQ for development tasks](tools/run-rabbitmq.sh)
10. [Script to start MongoDB Atlas for development tasks](tools/run-mongodb-atlas.sh)

### .NET packages

- **Microsoft.KernelMemory.WebClient:** .NET web client to call a running instance of Kernel Memory web service.

  [![Nuget package](https://img.shields.io/nuget/vpre/Microsoft.KernelMemory.WebClient)](https://www.nuget.org/packages/Microsoft.KernelMemory.WebClient/)
  [![Example code](https://img.shields.io/badge/example-code-blue)](https://github.com/microsoft/kernel-memory/tree/main/examples/001-dotnet-WebClient)

- **Microsoft.KernelMemory.Core:** Kernel Memory core library including all extensions, can be used to build custom pipelines and handlers, contains
  also the serverless client to use memory in a synchronous way without the web service.

  [![Nuget package](https://img.shields.io/nuget/vpre/Microsoft.KernelMemory.Core)](https://www.nuget.org/packages/Microsoft.KernelMemory.Core/)
  [![Example code](https://img.shields.io/badge/example-code-blue)](https://github.com/microsoft/kernel-memory/tree/main/examples/002-dotnet-Serverless)

- **Microsoft.KernelMemory.Service.AspNetCore:** an extension to load Kernel Memory into your ASP.NET apps.

  [![Nuget package](https://img.shields.io/nuget/vpre/Microsoft.KernelMemory.Service.AspNetCore)](https://www.nuget.org/packages/Microsoft.KernelMemory.Service.AspNetCore/)
  [![Example code](https://img.shields.io/badge/example-code-blue)](https://github.com/microsoft/kernel-memory/tree/main/examples/204-dotnet-ASP.NET-MVC-integration)

- **Microsoft.KernelMemory.SemanticKernelPlugin:** a Memory plugin for Semantic Kernel,
  replacing the original Semantic Memory available in SK.

  [![Nuget package](https://img.shields.io/nuget/vpre/Microsoft.KernelMemory.SemanticKernelPlugin)](https://www.nuget.org/packages/Microsoft.KernelMemory.SemanticKernelPlugin/)
  [![Example code](https://img.shields.io/badge/example-code-blue)](https://github.com/microsoft/kernel-memory/tree/main/examples/003-dotnet-SemanticKernel-plugin)

### Packages for Python, Java and other languages

Kernel Memory service offers a **Web API** out of the box, including the **OpenAPI
swagger** documentation that you can leverage to test the API and create custom
web clients. For instance, after starting the service locally, see http://127.0.0.1:9001/swagger/index.html.

A .NET Web Client and a Semantic Kernel plugin are available, see the nugets packages above.

A python package with a Web Client and Semantic Kernel plugin will soon be available.
We also welcome PR contributions to support more languages.

# Contributors

<!--
githubcontrib --repo kernel-memory --owner microsoft --showlogin true --sortBy login --cols 6 --imagesize 110
-->

[<img alt="aaronpowell" src="https://avatars.githubusercontent.com/u/434140?v=4&s=110" width="110">](https://github.com/aaronpowell) |[<img alt="afederici75" src="https://avatars.githubusercontent.com/u/13766049?v=4&s=110" width="110">](https://github.com/afederici75) |[<img alt="akordowski" src="https://avatars.githubusercontent.com/u/9746197?v=4&s=110" width="110">](https://github.com/akordowski) |[<img alt="alexibraimov" src="https://avatars.githubusercontent.com/u/59023460?v=4&s=110" width="110">](https://github.com/alexibraimov) |[<img alt="alkampfergit" src="https://avatars.githubusercontent.com/u/358545?v=4&s=110" width="110">](https://github.com/alkampfergit) |[<img alt="amomra" src="https://avatars.githubusercontent.com/u/11981363?v=4&s=110" width="110">](https://github.com/amomra) |
:---: |:---: |:---: |:---: |:---: |:---: |
[aaronpowell](https://github.com/aaronpowell) |[afederici75](https://github.com/afederici75) |[akordowski](https://github.com/akordowski) |[alexibraimov](https://github.com/alexibraimov) |[alkampfergit](https://github.com/alkampfergit) |[amomra](https://github.com/amomra) |

[<img alt="anthonypuppo" src="https://avatars.githubusercontent.com/u/6828951?v=4&s=110" width="110">](https://github.com/anthonypuppo) |[<img alt="chaelli" src="https://avatars.githubusercontent.com/u/878151?v=4&s=110" width="110">](https://github.com/chaelli) |[<img alt="cherchyk" src="https://avatars.githubusercontent.com/u/1703275?v=4&s=110" width="110">](https://github.com/cherchyk) |[<img alt="coryisakson" src="https://avatars.githubusercontent.com/u/303811?v=4&s=110" width="110">](https://github.com/coryisakson) |[<img alt="crickman" src="https://avatars.githubusercontent.com/u/66376200?v=4&s=110" width="110">](https://github.com/crickman) |[<img alt="dependabot[bot]" src="https://avatars.githubusercontent.com/in/29110?v=4&s=110" width="110">](https://github.com/apps/dependabot) |
:---: |:---: |:---: |:---: |:---: |:---: |
[anthonypuppo](https://github.com/anthonypuppo) |[chaelli](https://github.com/chaelli) |[cherchyk](https://github.com/cherchyk) |[coryisakson](https://github.com/coryisakson) |[crickman](https://github.com/crickman) |[dependabot[bot]](https://github.com/apps/dependabot) |

[<img alt="dluc" src="https://avatars.githubusercontent.com/u/371009?v=4&s=110" width="110">](https://github.com/dluc) |[<img alt="DM-98" src="https://avatars.githubusercontent.com/u/10290906?v=4&s=110" width="110">](https://github.com/DM-98) |[<img alt="EelcoKoster" src="https://avatars.githubusercontent.com/u/3356003?v=4&s=110" width="110">](https://github.com/EelcoKoster) |[<img alt="Foorcee" src="https://avatars.githubusercontent.com/u/5587062?v=4&s=110" width="110">](https://github.com/Foorcee) |[<img alt="GraemeJones104" src="https://avatars.githubusercontent.com/u/79144786?v=4&s=110" width="110">](https://github.com/GraemeJones104) |[<img alt="jurepurgar" src="https://avatars.githubusercontent.com/u/6506920?v=4&s=110" width="110">](https://github.com/jurepurgar) |
:---: |:---: |:---: |:---: |:---: |:---: |
[dluc](https://github.com/dluc) |[DM-98](https://github.com/DM-98) |[EelcoKoster](https://github.com/EelcoKoster) |[Foorcee](https://github.com/Foorcee) |[GraemeJones104](https://github.com/GraemeJones104) |[jurepurgar](https://github.com/jurepurgar) |

[<img alt="kbeaugrand" src="https://avatars.githubusercontent.com/u/9513635?v=4&s=110" width="110">](https://github.com/kbeaugrand) |[<img alt="koteus" src="https://avatars.githubusercontent.com/u/428201?v=4&s=110" width="110">](https://github.com/koteus) |[<img alt="KSemenenko" src="https://avatars.githubusercontent.com/u/4385716?v=4&s=110" width="110">](https://github.com/KSemenenko) |[<img alt="lecramr" src="https://avatars.githubusercontent.com/u/20584823?v=4&s=110" width="110">](https://github.com/lecramr) |[<img alt="luismanez" src="https://avatars.githubusercontent.com/u/9392197?v=4&s=110" width="110">](https://github.com/luismanez) |[<img alt="marcominerva" src="https://avatars.githubusercontent.com/u/3522534?v=4&s=110" width="110">](https://github.com/marcominerva) |
:---: |:---: |:---: |:---: |:---: |:---: |
[kbeaugrand](https://github.com/kbeaugrand) |[koteus](https://github.com/koteus) |[KSemenenko](https://github.com/KSemenenko) |[lecramr](https://github.com/lecramr) |[luismanez](https://github.com/luismanez) |[marcominerva](https://github.com/marcominerva) |

[<img alt="neel015" src="https://avatars.githubusercontent.com/u/34688460?v=4&s=110" width="110">](https://github.com/neel015) |[<img alt="pascalberger" src="https://avatars.githubusercontent.com/u/2190718?v=4&s=110" width="110">](https://github.com/pascalberger) |[<img alt="pawarsum12" src="https://avatars.githubusercontent.com/u/136417839?v=4&s=110" width="110">](https://github.com/pawarsum12) |[<img alt="pradeepr-roboticist" src="https://avatars.githubusercontent.com/u/6598307?v=4&s=110" width="110">](https://github.com/pradeepr-roboticist) |[<img alt="qihangnet" src="https://avatars.githubusercontent.com/u/1784873?v=4&s=110" width="110">](https://github.com/qihangnet) |[<img alt="roldengarm" src="https://avatars.githubusercontent.com/u/37638588?v=4&s=110" width="110">](https://github.com/roldengarm) |
:---: |:---: |:---: |:---: |:---: |:---: |
[neel015](https://github.com/neel015) |[pascalberger](https://github.com/pascalberger) |[pawarsum12](https://github.com/pawarsum12) |[pradeepr-roboticist](https://github.com/pradeepr-roboticist) |[qihangnet](https://github.com/qihangnet) |[roldengarm](https://github.com/roldengarm) |

[<img alt="slapointe" src="https://avatars.githubusercontent.com/u/1054412?v=4&s=110" width="110">](https://github.com/slapointe) |[<img alt="slorello89" src="https://avatars.githubusercontent.com/u/42971704?v=4&s=110" width="110">](https://github.com/slorello89) |[<img alt="spenavajr" src="https://avatars.githubusercontent.com/u/96045491?v=4&s=110" width="110">](https://github.com/spenavajr) |[<img alt="TaoChenOSU" src="https://avatars.githubusercontent.com/u/12570346?v=4&s=110" width="110">](https://github.com/TaoChenOSU) |[<img alt="teresaqhoang" src="https://avatars.githubusercontent.com/u/125500434?v=4&s=110" width="110">](https://github.com/teresaqhoang) |[<img alt="v-msamovendyuk" src="https://avatars.githubusercontent.com/u/61688766?v=4&s=110" width="110">](https://github.com/v-msamovendyuk) |
:---: |:---: |:---: |:---: |:---: |:---: |
[slapointe](https://github.com/slapointe) |[slorello89](https://github.com/slorello89) |[spenavajr](https://github.com/spenavajr) |[TaoChenOSU](https://github.com/TaoChenOSU) |[teresaqhoang](https://github.com/teresaqhoang) |[v-msamovendyuk](https://github.com/v-msamovendyuk) |

[<img alt="Valkozaur" src="https://avatars.githubusercontent.com/u/58659526?v=4&s=110" width="110">](https://github.com/Valkozaur) |[<img alt="vicperdana" src="https://avatars.githubusercontent.com/u/7114832?v=4&s=110" width="110">](https://github.com/vicperdana) |[<img alt="westdavidr" src="https://avatars.githubusercontent.com/u/669668?v=4&s=110" width="110">](https://github.com/westdavidr) |[<img alt="xbotter" src="https://avatars.githubusercontent.com/u/3634877?v=4&s=110" width="110">](https://github.com/xbotter) |
:---: |:---: |:---: |:---: |
[Valkozaur](https://github.com/Valkozaur) |[vicperdana](https://github.com/vicperdana) |[westdavidr](https://github.com/westdavidr) |[xbotter](https://github.com/xbotter) |
