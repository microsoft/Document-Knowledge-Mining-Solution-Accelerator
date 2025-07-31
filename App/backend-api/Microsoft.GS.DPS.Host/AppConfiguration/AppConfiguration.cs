﻿using Azure.Identity;
using Microsoft.Extensions.Azure;
using Microsoft.GS.DPSHost.AppConfiguration;
using Microsoft.GS.DPSHost.Helpers;

namespace Microsoft.GS.DPSHost.AppConfiguration
{
    public class AppConfiguration
    {
        public static void Config(IHostApplicationBuilder builder)
        {
            //Read ServiceConfiguration files - appsettings.json / appsettings.Development.json
            //builder.Configuration.AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);
            //builder.Configuration.AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true);
            var servicesConfig = builder.Configuration.GetSection("Application:Services").Get<Services>();
            string appEnv = servicesConfig?.APP_ENV;

            //Read AppConfiguration with managed Identity
            builder.Configuration.AddAzureAppConfiguration(options =>
            {
                options.Connect(new Uri(builder.Configuration["ConnectionStrings:AppConfig"]), AzureCredentialHelper.GetAzureCredential(appEnv));
            });

            //Read ServiceConfiguration
            builder.Services.Configure<AIServices>(builder.Configuration.GetSection("Application:AIServices"));
            builder.Services.Configure<Services>(builder.Configuration.GetSection("Application:Services"));
        }


    }
}
