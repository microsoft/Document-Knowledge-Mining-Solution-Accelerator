using Microsoft.GS.DPS.Model.ChatHost;
using Microsoft.GS.DPS.API;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http.HttpResults;
using System.Text;
using System.Text.Json;
using Microsoft.GS.DPSHost.Helpers;

namespace Microsoft.GS.DPSHost.API
{
    public class Chat
    {
        public static void AddAPIs(WebApplication app)
        {
            //RegisterAsync the chat API
            app.MapPost("/chat", async (ChatRequest request,
                                        ChatRequestValidator validator,
                                        ChatHost chatHost,
                                        TelemetryHelper telemetryHelper,
                                        ILogger<Chat> logger) =>
            {
                try
                {
                    if (validator.Validate(request).IsValid == false)
                    {
                        telemetryHelper.TrackEvent("ChatRequestValidationFailed", new Dictionary<string, string>
                        {
                            { "endpoint", "/chat" }
                        });
                        return Results.BadRequest();
                    }

                    var result = await chatHost.Chat(request);
                    
                    // Track successful chat request
                    telemetryHelper.TrackEvent("ChatRequestSuccess", new Dictionary<string, string>
                    {
                        { "chatSessionId", result.ChatSessionId ?? "unknown" },
                        { "documentCount", result.DocumentIds?.Length.ToString() ?? "0" }
                    });

                    // Set correlation ID for tracing
                    if (!string.IsNullOrEmpty(result.ChatSessionId))
                    {
                        telemetryHelper.SetActivityTag("chatSessionId", result.ChatSessionId);
                    }

                    return Results.Ok<ChatResponse>(result);
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Error processing chat request");
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "endpoint", "/chat" },
                        { "errorType", ex.GetType().Name }
                    });
                    throw;
                }
            })
            .DisableAntiforgery();


            ///<summary>
            //RegisterAsync the chat API
            //</summary>
            app.MapPost("/chatAsync", async (HttpContext ctx, 
                                             ChatRequest request, 
                                             ChatRequestValidator validator,
                                             ChatHost chatHost,
                                             TelemetryHelper telemetryHelper,
                                             ILogger<Chat> logger) =>
            {
                try
                {
                    if (validator.Validate(request).IsValid == false)
                    {
                        telemetryHelper.TrackEvent("ChatAsyncRequestValidationFailed", new Dictionary<string, string>
                        {
                            { "endpoint", "/chatAsync" }
                        });
                        return Results.BadRequest();
                    }

                    ctx.Response.ContentType = "text/plain";

                    //Make a response as a stream
                    var result = chatHost.ChatAsync(request).Result;

                    //Create a dynamic object to store the response
                    var response = new
                    {
                        result.ChatSessionId,
                        result.DocumentIds,
                        result.SuggestingQuestions
                    };

                    //Add the response to the header
                    ctx.Response.Headers.Add("RESPONSE", JsonSerializer.Serialize(response));

                    // Track successful chat async request
                    telemetryHelper.TrackEvent("ChatAsyncRequestSuccess", new Dictionary<string, string>
                    {
                        { "chatSessionId", result.ChatSessionId ?? "unknown" },
                        { "documentCount", result.DocumentIds?.Length.ToString() ?? "0" }
                    });

                    // Set correlation ID for tracing
                    if (!string.IsNullOrEmpty(result.ChatSessionId))
                    {
                        telemetryHelper.SetActivityTag("chatSessionId", result.ChatSessionId);
                    }

                    // Stream the response
                    await foreach (var word in result.AnswerWords)
                    {
                        await ctx.Response.WriteAsync(word);
                        await ctx.Response.WriteAsync(" ");
                    }
                    return Results.Ok();
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Error processing chat async request");
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "endpoint", "/chatAsync" },
                        { "errorType", ex.GetType().Name }
                    });
                    throw;
                }
            })
            .DisableAntiforgery();
        }
    }
}
