using FluentValidation;
using Microsoft.Extensions.Options;
using Microsoft.GS.DPS.Model.UserInterface;
using Microsoft.GS.DPS.Storage.AISearch;
using Microsoft.GS.DPS.Storage.ChatSessions;
using Microsoft.GS.DPS.Storage.Document;
using Microsoft.GS.DPSHost.AppConfiguration;
using Microsoft.GS.DPSHost.Helpers;
using Microsoft.KernelMemory;
using Microsoft.SemanticKernel;
using MongoDB.Driver;
using Microsoft.GS.DPS.Handlers;

namespace Microsoft.GS.DPSHost.ServiceConfiguration
{
    public class ServiceDependencies
    {
        public static void Inject(IHostApplicationBuilder builder)
        {
            builder.Services
                .AddValidatorsFromAssemblyContaining<PagingRequestValidator>()
                .AddSingleton<Microsoft.GS.DPS.API.KernelMemory>()
                .AddSingleton<Microsoft.GS.DPS.API.ChatHost>()
                .AddSingleton<Microsoft.GS.DPS.API.UserInterface.Documents>()
                .AddSingleton<Microsoft.GS.DPS.API.UserInterface.DataCacheManager>()
                //.AddSingleton<Microsoft.KernelMemory.KernelMemoryConfig>(x =>
                //{
                //    return builder.Configuration.GetSection("KernelMemory").Get<Microsoft.KernelMemory.KernelMemoryConfig>() ??
                //           throw new InvalidOperationException("Unable to load KernelMemory configuration");
                //})
                .AddSingleton<Microsoft.SemanticKernel.Kernel>(x =>
                {
                    var aiService = x.GetRequiredService<IOptions<AIServices>>().Value;
                    return Kernel.CreateBuilder()
                                 .AddAzureOpenAIChatCompletion(deploymentName: builder.Configuration.GetSection("Application:AIServices:GPT-4o-mini")["ModelName"] ?? "",
                                                              endpoint: builder.Configuration.GetSection("Application:AIServices:GPT-4o-mini")["Endpoint"] ?? "",
                                                              credentials: AzureCredentialHelper.GetAzureCredential())

                                 .Build();
                })
                .AddSingleton<ChatSessionRepository>(x =>
                {
                    var services = x.GetRequiredService<IOptions<Services>>().Value;

                    return new ChatSessionRepository(
                                                new MongoClient(services.PersistentStorage.CosmosMongo.ConnectionString ?? "")
                                                                        .GetDatabase(services.PersistentStorage.CosmosMongo.Collections.ChatHistory.Database ?? ""),
                                                                                        collectionName: services.PersistentStorage.CosmosMongo.Collections.ChatHistory.Collection ?? ""

                                                   );
                })
                .AddSingleton<DocumentRepository>(x =>
                {
                    var services = x.GetRequiredService<IOptions<Services>>().Value;
                    return new DocumentRepository(
                                                new MongoClient(services.PersistentStorage.CosmosMongo.ConnectionString ?? "")
                                                                        .GetDatabase(services.PersistentStorage.CosmosMongo.Collections.DocumentManager.Database ?? ""),
                                                                                    collectionName: services.PersistentStorage.CosmosMongo.Collections.DocumentManager.Collection ?? ""
                                                   );


                })
                .AddSingleton<MemoryServerless>(x =>
                {
                    var azureBlobConfig = x.GetRequiredService<IOptions<AzureBlobsConfig>>().Value;
                    var azureOpenAIConfig = x.GetRequiredService<IOptionsMonitor<AzureOpenAIConfig>>();
                    var azureOpenAIEmbeddingConfig = azureOpenAIConfig.Get("Embedding");
                    var azureOpenAITextConfig = azureOpenAIConfig.Get("Text");
                    var azureAISearchConfig = x.GetRequiredService<IOptions<Microsoft.KernelMemory.AzureAISearchConfig>>().Value;
                    var azureAIDocIntelConfig = x.GetRequiredService<IOptions<AzureAIDocIntelConfig>>().Value;
                    var kernelMemoryConfig = x.GetRequiredService<IOptions<Microsoft.KernelMemory.KernelMemoryConfig>>().Value
                                                ?? throw new InvalidOperationException("Unable to load KernelMemory configuration");

                    var kmBuilder = new KernelMemoryBuilder()
                                .WithAzureBlobsDocumentStorage(azureBlobConfig)
                                .WithAzureOpenAITextEmbeddingGeneration(azureOpenAIEmbeddingConfig)
                                .WithAzureOpenAITextGeneration(azureOpenAITextConfig)
                                .WithAzureAISearchMemoryDb(azureAISearchConfig)
                                .WithAzureAIDocIntel(azureAIDocIntelConfig)
                                .Configure(builder => builder.Services.AddLogging(l =>
                                {
                                    l.SetMinimumLevel(LogLevel.Error);
                                    l.AddSimpleConsole(c => c.SingleLine = true);
                                }))
                                .Build<MemoryServerless>();

                    var keywordHandler = new KeywordExtractingHandler(
                        stepName: "keyword_extract",
                        orchestrator: kmBuilder.Orchestrator,
                        config: kernelMemoryConfig
                    );
                    
                    // Add the handler instance instead of using generic method
                    kmBuilder.Orchestrator.AddHandler(keywordHandler);
                    return kmBuilder;

                })
                .AddSingleton<TagUpdater>(x =>
                {
                    var services = x.GetRequiredService<IOptions<Services>>().Value;
                    return new TagUpdater(services.AzureAISearch.Endpoint, AzureCredentialHelper.GetAzureCredential());

                })

                ;
        }
    }
}
