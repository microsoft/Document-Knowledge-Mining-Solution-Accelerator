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
            app.MapPost("/chat", async (HttpContext httpContext,
                                        ChatRequest request,
                                        ChatRequestValidator validator,
                                        ChatHost chatHost,
                                        TelemetryHelper telemetryHelper,
                                        ILogger<Chat> logger) =>
            {
                // Generate unique request ID for tracking
                var requestId = httpContext.TraceIdentifier;
                telemetryHelper.SetActivityTag("requestId", requestId);
                var startTime = DateTimeOffset.UtcNow;
                
                // Trace: Request received
                logger.LogInformation("[{RequestId}] Chat request received. Endpoint: /chat, HasSessionId: {HasSessionId}, DocumentIds: {DocumentCount}",
                    requestId, 
                    !string.IsNullOrEmpty(request.ChatSessionId),
                    request.DocumentIds?.Length ?? 0);
                
                // Track request started
                telemetryHelper.TrackEvent("ChatRequestStarted", new Dictionary<string, string>
                {
                    { "requestId", requestId },
                    { "endpoint", "/chat" },
                    { "hasSessionId", (!string.IsNullOrEmpty(request.ChatSessionId)).ToString() },
                    { "documentCount", (request.DocumentIds?.Length ?? 0).ToString() }
                });
                
                try
                {
                    // Trace: Starting validation
                    logger.LogDebug("[{RequestId}] Validating chat request", requestId);
                    
                    // Validate request
                    var validationResult = validator.Validate(request);
                    if (!validationResult.IsValid)
                    {
                        var errors = string.Join("; ", validationResult.Errors.Select(e => e.ErrorMessage));
                        
                        // Trace: Validation failed
                        logger.LogWarning("[{RequestId}] Chat request validation failed. Errors: {ValidationErrors}",
                            requestId, errors);
                        
                        telemetryHelper.TrackEvent("ChatRequestValidationFailed", new Dictionary<string, string>
                        {
                            { "requestId", requestId },
                            { "endpoint", "/chat" },
                            { "validationErrors", errors }
                        });
                        return Results.BadRequest();
                    }
                    
                    // Trace: Validation passed, processing request
                    logger.LogInformation("[{RequestId}] Request validation passed. Calling chat host...", requestId);

                    var result = await chatHost.Chat(request);
                    var duration = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: Request completed successfully
                    logger.LogInformation("[{RequestId}] Chat request completed successfully. Duration: {Duration}s, ChatSessionId: {ChatSessionId}, Documents: {DocumentCount}, AnswerLength: {AnswerLength}",
                        requestId,
                        duration.ToString("F2"),
                        result.ChatSessionId ?? "unknown",
                        result.DocumentIds?.Length ?? 0,
                        result.Answer?.Length ?? 0);
                    
                    // Track successful chat request with metrics
                    telemetryHelper.TrackEvent("ChatRequestSuccess", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "chatSessionId", result.ChatSessionId ?? "unknown" },
                        { "documentCount", result.DocumentIds?.Length.ToString() ?? "0" },
                        { "hasSuggestedQuestions", (result.SuggestingQuestions?.Length > 0).ToString() },
                        { "answerLength", result.Answer?.Length.ToString() ?? "0" },
                        { "duration", duration.ToString("F2") }
                    }, new Dictionary<string, double>
                    {
                        { "ResponseTimeSeconds", duration },
                        { "DocumentsReferenced", result.DocumentIds?.Length ?? 0 }
                    });

                    // Set correlation ID for tracing
                    if (!string.IsNullOrEmpty(result.ChatSessionId))
                    {
                        telemetryHelper.SetActivityTag("chatSessionId", result.ChatSessionId);
                    }

                    // Track performance metrics
                    if (duration > 60)
                    {
                        // Trace: Slow response warning
                        logger.LogWarning("[{RequestId}] SLOW RESPONSE DETECTED: Chat request took {Duration}s (threshold: 60s). DocumentCount: {DocumentCount}",
                            requestId,
                            duration.ToString("F2"),
                            result.DocumentIds?.Length ?? 0);
                        
                        telemetryHelper.TrackEvent("ChatRequestSlowResponse", new Dictionary<string, string>
                        {
                            { "requestId", requestId },
                            { "duration", duration.ToString("F2") },
                            { "documentCount", result.DocumentIds?.Length.ToString() ?? "0" }
                        });
                    }
                    else if (duration > 30)
                    {
                        // Trace: Performance warning for moderately slow requests
                        logger.LogInformation("[{RequestId}] Moderate response time: {Duration}s",
                            requestId, duration.ToString("F2"));
                    }

                    return Results.Ok<ChatResponse>(result);
                }
                catch (TimeoutException ex)
                {
                    var elapsedTime = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: Timeout with details
                    logger.LogError(ex, "[{RequestId}] TIMEOUT: Chat request timed out after {ElapsedTime}s. Endpoint: /chat, Message: {ErrorMessage}",
                        requestId,
                        elapsedTime.ToString("F2"),
                        ex.Message);
                    
                    telemetryHelper.TrackEvent("ChatRequestTimeout", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/chat" },
                        { "elapsedTime", elapsedTime.ToString("F2") },
                        { "errorMessage", ex.Message }
                    });
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/chat" },
                        { "errorType", "TimeoutException" }
                    });
                    throw;
                }
                catch (ArgumentException ex)
                {
                    // Trace: Invalid argument with parameter details
                    logger.LogError(ex, "[{RequestId}] INVALID ARGUMENT: Chat request failed due to invalid parameter. Endpoint: /chat, Parameter: {ParamName}, Message: {ErrorMessage}",
                        requestId,
                        ex.ParamName ?? "unknown",
                        ex.Message);
                    
                    telemetryHelper.TrackEvent("ChatRequestInvalidArgument", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/chat" },
                        { "paramName", ex.ParamName ?? "unknown" },
                        { "errorMessage", ex.Message }
                    });
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/chat" },
                        { "errorType", "ArgumentException" }
                    });
                    throw;
                }
                catch (Exception ex)
                {
                    var elapsedTime = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: General error with full context
                    logger.LogError(ex, "[{RequestId}] CHAT REQUEST FAILED: Unexpected error after {ElapsedTime}s. Endpoint: /chat, ErrorType: {ErrorType}, Message: {ErrorMessage}, StackTrace: {StackTrace}",
                        requestId,
                        elapsedTime.ToString("F2"),
                        ex.GetType().Name,
                        ex.Message,
                        ex.StackTrace?.Substring(0, Math.Min(500, ex.StackTrace?.Length ?? 0)) ?? "N/A");
                    
                    telemetryHelper.TrackEvent("ChatRequestFailed", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/chat" },
                        { "errorType", ex.GetType().Name },
                        { "errorMessage", ex.Message },
                        { "elapsedTime", elapsedTime.ToString("F2") },
                        { "innerException", ex.InnerException?.Message ?? "none" }
                    });
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "requestId", requestId },
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
                // Generate unique request ID for tracking
                var requestId = ctx.TraceIdentifier;
                telemetryHelper.SetActivityTag("requestId", requestId);
                var startTime = DateTimeOffset.UtcNow;
                
                // Trace: Async request received
                logger.LogInformation("[{RequestId}] Chat ASYNC request received. Endpoint: /chatAsync, HasSessionId: {HasSessionId}, DocumentIds: {DocumentCount}",
                    requestId,
                    !string.IsNullOrEmpty(request.ChatSessionId),
                    request.DocumentIds?.Length ?? 0);
                
                // Track async request started
                telemetryHelper.TrackEvent("ChatAsyncRequestStarted", new Dictionary<string, string>
                {
                    { "requestId", requestId },
                    { "endpoint", "/chatAsync" },
                    { "hasSessionId", (!string.IsNullOrEmpty(request.ChatSessionId)).ToString() },
                    { "documentCount", (request.DocumentIds?.Length ?? 0).ToString() }
                });
                
                try
                {
                    // Trace: Starting validation
                    logger.LogDebug("[{RequestId}] Validating chat async request", requestId);
                    
                    var validationResult = validator.Validate(request);
                    if (!validationResult.IsValid)
                    {
                        var errors = string.Join("; ", validationResult.Errors.Select(e => e.ErrorMessage));
                        
                        // Trace: Validation failed
                        logger.LogWarning("[{RequestId}] Chat async request validation failed. Errors: {ValidationErrors}",
                            requestId, errors);
                        
                        telemetryHelper.TrackEvent("ChatAsyncRequestValidationFailed", new Dictionary<string, string>
                        {
                            { "requestId", requestId },
                            { "endpoint", "/chatAsync" },
                            { "validationErrors", errors }
                        });
                        return Results.BadRequest();
                    }

                    // Trace: Validation passed, preparing streaming response
                    logger.LogInformation("[{RequestId}] Request validation passed. Preparing streaming response...", requestId);
                    
                    ctx.Response.ContentType = "text/plain";

                    //Make a response as a stream
                    var result = chatHost.ChatAsync(request).Result;
                    var duration = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: Response metadata ready
                    logger.LogInformation("[{RequestId}] Chat async response ready. Duration: {Duration}s, ChatSessionId: {ChatSessionId}, Documents: {DocumentCount}",
                        requestId,
                        duration.ToString("F2"),
                        result.ChatSessionId ?? "unknown",
                        result.DocumentIds?.Length ?? 0);

                    //Create a dynamic object to store the response
                    var response = new
                    {
                        result.ChatSessionId,
                        result.DocumentIds,
                        result.SuggestingQuestions
                    };

                    //Add the response to the header
                    ctx.Response.Headers.Add("RESPONSE", JsonSerializer.Serialize(response));

                    // Track successful chat async request with metrics
                    telemetryHelper.TrackEvent("ChatAsyncRequestSuccess", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "chatSessionId", result.ChatSessionId ?? "unknown" },
                        { "documentCount", result.DocumentIds?.Length.ToString() ?? "0" },
                        { "hasSuggestedQuestions", (result.SuggestingQuestions?.Length > 0).ToString() },
                        { "streamingResponse", "true" },
                        { "duration", duration.ToString("F2") }
                    }, new Dictionary<string, double>
                    {
                        { "ResponseTimeSeconds", duration },
                        { "DocumentsReferenced", result.DocumentIds?.Length ?? 0 }
                    });

                    // Set correlation ID for tracing
                    if (!string.IsNullOrEmpty(result.ChatSessionId))
                    {
                        telemetryHelper.SetActivityTag("chatSessionId", result.ChatSessionId);
                    }

                    // Trace: Beginning streaming
                    logger.LogDebug("[{RequestId}] Starting to stream response words...", requestId);
                    
                    // Stream the response
                    var wordCount = 0;
                    await foreach (var word in result.AnswerWords)
                    {
                        await ctx.Response.WriteAsync(word);
                        await ctx.Response.WriteAsync(" ");
                        wordCount++;
                    }
                    
                    // Trace: Streaming completed
                    logger.LogInformation("[{RequestId}] Streaming completed. Total words streamed: {WordCount}",
                        requestId, wordCount);
                    
                    return Results.Ok();
                }
                catch (TimeoutException ex)
                {
                    var elapsedTime = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: Timeout with details
                    logger.LogError(ex, "[{RequestId}] TIMEOUT: Chat async request timed out after {ElapsedTime}s. Endpoint: /chatAsync, Message: {ErrorMessage}",
                        requestId,
                        elapsedTime.ToString("F2"),
                        ex.Message);
                    
                    telemetryHelper.TrackEvent("ChatAsyncRequestTimeout", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/chatAsync" },
                        { "elapsedTime", elapsedTime.ToString("F2") },
                        { "errorMessage", ex.Message }
                    });
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/chatAsync" },
                        { "errorType", "TimeoutException" }
                    });
                    throw;
                }
                catch (Exception ex)
                {
                    var elapsedTime = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: General error with full context
                    logger.LogError(ex, "[{RequestId}] CHAT ASYNC REQUEST FAILED: Unexpected error after {ElapsedTime}s. Endpoint: /chatAsync, ErrorType: {ErrorType}, Message: {ErrorMessage}, StackTrace: {StackTrace}",
                        requestId,
                        elapsedTime.ToString("F2"),
                        ex.GetType().Name,
                        ex.Message,
                        ex.StackTrace?.Substring(0, Math.Min(500, ex.StackTrace?.Length ?? 0)) ?? "N/A");
                    
                    telemetryHelper.TrackEvent("ChatAsyncRequestFailed", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/chatAsync" },
                        { "errorType", ex.GetType().Name },
                        { "errorMessage", ex.Message },
                        { "elapsedTime", elapsedTime.ToString("F2") },
                        { "innerException", ex.InnerException?.Message ?? "none" }
                    });
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "requestId", requestId },
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
