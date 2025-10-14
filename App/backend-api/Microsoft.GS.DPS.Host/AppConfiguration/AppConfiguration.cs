using Azure.Identity;
using Microsoft.Extensions.Azure;
using Microsoft.GS.DPSHost.AppConfiguration;
using Microsoft.GS.DPSHost.Helpers;
using Microsoft.KernelMemory;

namespace Microsoft.GS.DPSHost.AppConfiguration
{
    public class AppConfiguration
    {
        public static void Config(IHostApplicationBuilder builder)
        {
            //Read ServiceConfiguration files - appsettings.json / appsettings.Development.json
            //builder.Configuration.AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);
            //builder.Configuration.AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true);


            //Read AppConfiguration with managed Identity
            builder.Configuration.AddAzureAppConfiguration(options =>
            {
                options.Connect(new Uri(builder.Configuration["ConnectionStrings:AppConfig"]), AzureCredentialHelper.GetAzureCredential());
            });

            //Read ServiceConfiguration
            builder.Services.Configure<AIServices>(builder.Configuration.GetSection("Application:AIServices"));
            builder.Services.Configure<Services>(builder.Configuration.GetSection("Application:Services"));
            builder.Services.Configure<KernelMemoryConfig>(builder.Configuration.GetSection("KernelMemory"));
            builder.Services.Configure<AzureBlobsConfig>(builder.Configuration.GetSection("KernelMemory:Services:AzureBlobs"));
            builder.Services.Configure<AzureOpenAIConfig>("Embedding", builder.Configuration.GetSection("KernelMemory:Services:AzureOpenAIEmbedding"));
            builder.Services.Configure<AzureOpenAIConfig>("Text", builder.Configuration.GetSection("KernelMemory:Services:AzureOpenAIText"));
            builder.Services.Configure<AzureAISearchConfig>(builder.Configuration.GetSection("KernelMemory:Services:AzureAISearch"));
            builder.Services.Configure<AzureAIDocIntelConfig>(builder.Configuration.GetSection("KernelMemory:Services:AzureAIDocIntel"));
        }


    }
}
