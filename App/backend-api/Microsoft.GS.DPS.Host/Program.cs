using Microsoft.GS.DPSHost.AppConfiguration;
using Microsoft.GS.DPSHost.ServiceConfiguration;
using Microsoft.GS.DPSHost.API;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using System.Reflection;
using Microsoft.GS.DPS.Storage.Document;
using NSwag.AspNetCore;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.ApplicationInsights.AspNetCore.Extensions;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

//Load Inject Settings and Load AppConfiguration Objects
AppConfiguration.Config(builder);

// Configure Application Insights - Always register to ensure TelemetryClient is available for DI
var connectionString = builder.Configuration["ApplicationInsights:ConnectionString"];
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    if (!string.IsNullOrEmpty(connectionString))
    {
        options.ConnectionString = connectionString;
        options.EnableAdaptiveSampling = builder.Configuration.GetValue<bool>("ApplicationInsights:EnableAdaptiveSampling", true);
        options.EnablePerformanceCounterCollectionModule = builder.Configuration.GetValue<bool>("ApplicationInsights:EnablePerformanceCounterCollectionModule", true);
        options.EnableQuickPulseMetricStream = builder.Configuration.GetValue<bool>("ApplicationInsights:EnableQuickPulseMetricStream", true);
    }
});

// Configure logging
if (!string.IsNullOrEmpty(connectionString))
{
    builder.Logging.AddApplicationInsights();
}
builder.Logging.AddConsole();
builder.Logging.AddDebug();

//Bson Register Class Maps
//MongoDbConfig.RegisterClassMaps();

//Add Services (Dependency Injection)
ServiceDependencies.Inject(builder);


// Inject Kestrel server options
builder.Services.Configure<KestrelServerOptions>(options =>
{
    //allow  to upload files up to 500 MB
    options.Limits.MaxRequestBodySize = 500 * 1024 * 1024; // 500 MB
    options.Limits.KeepAliveTimeout = TimeSpan.FromMinutes(20);
    options.Limits.RequestHeadersTimeout = TimeSpan.FromMinutes(20);
});

// Configure FormOptions to increase the maximum allowed size for multipart body length
builder.Services.Configure<FormOptions>(options =>
{
    options.MultipartBodyLengthLimit = 500 * 1024 * 1024; // 500 MB
});

// Enable Corss-Origin Requests
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll",
        builder => builder.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

var app = builder.Build();

// Add Minimum API Services
Operation.AddAPIs(app);
KernelMemory.AddAPIs(app);
Chat.AddAPIs(app);
UserInterface.AddAPIs(app);

// Inject the HTTP request pipeline.
//if (app.Environment.IsDevelopment())
//{

app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "API V1");
    options.RoutePrefix = string.Empty;
});

//}

app.UseCors("AllowAll");
app.UseHttpsRedirection();
app.Run();

