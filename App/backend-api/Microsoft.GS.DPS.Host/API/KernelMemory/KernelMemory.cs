using Microsoft.GS.DPSHost.AppConfiguration;
using Microsoft.Extensions.Options;
using Microsoft.KernelMemory;
using Microsoft.Net.Http.Headers;
using System.Text.Json;
using System.Text;
using Microsoft.KernelMemory.Context;
using Microsoft.GS.DPS.Model.KernelMemory;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.GS.DPS.Storage.Document;
using HeyRed.Mime;
using Microsoft.GS.DPSHost.Helpers;

namespace Microsoft.GS.DPSHost.API
{
    //Define File Upload and Ask API
    public class KernelMemory
    {
        public static void AddAPIs(WebApplication app)
        {
            //Registration the files
            app.MapPost("/Documents/ImportDocument", async (HttpContext httpContext,
                                                            IFormFile file,
                                                            DPS.API.KernelMemory kernelMemory,
                                                            TelemetryHelper telemetryHelper,
                                                            ILogger<KernelMemory> logger
                                                            ) =>
            {
                // Generate unique request ID for tracking
                var requestId = httpContext.TraceIdentifier;
                telemetryHelper.SetActivityTag("requestId", requestId);
                var startTime = DateTimeOffset.UtcNow;
                
                // Trace: Document import request received
                logger.LogInformation("[{RequestId}] Document import request received. Endpoint: /Documents/ImportDocument, FileName: {FileName}, FileSize: {FileSize} bytes, ContentType: {ContentType}",
                    requestId,
                    file?.FileName ?? "unknown",
                    file?.Length ?? 0,
                    file?.ContentType ?? "unknown");
                
                // Track document import started
                telemetryHelper.TrackEvent("DocumentImportStarted", new Dictionary<string, string>
                {
                    { "requestId", requestId },
                    { "endpoint", "/Documents/ImportDocument" },
                    { "fileName", file?.FileName ?? "unknown" },
                    { "fileSize", file?.Length.ToString() ?? "0" }
                });
                
                try
                {
                    var fileStream = file.OpenReadStream();
                    //Set Stream Position to 0
                    fileStream.Seek(0, SeekOrigin.Begin);

                    // Trace: File stream opened
                    logger.LogDebug("[{RequestId}] File stream opened successfully", requestId);
                    
                    // Verify and set ContentType if empty
                    var contentType = file.ContentType;
                    var fileExtension = Path.GetExtension(file.FileName);

                    if (string.IsNullOrEmpty(contentType))
                    {
                        contentType = MimeTypesMap.GetMimeType(fileExtension);
                        
                        // Trace: Content type inferred
                        logger.LogDebug("[{RequestId}] Content type was empty, inferred as: {ContentType} from extension: {FileExtension}",
                            requestId, contentType, fileExtension);
                    }


                    //Check supported file types
                    var allowedExtensions = new string[] { ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".pdf", ".tif", ".tiff", ".jpg", ".jpeg", ".png", ".bmp", ".txt" };

                    if (!allowedExtensions.Contains(fileExtension))
                    {
                        // Trace: Unsupported file type
                        logger.LogWarning("[{RequestId}] UNSUPPORTED FILE TYPE: Extension '{FileExtension}' is not allowed. FileName: {FileName}, AllowedExtensions: {AllowedExtensions}",
                            requestId,
                            fileExtension,
                            file.FileName,
                            string.Join(", ", allowedExtensions));
                        
                        telemetryHelper.TrackEvent("DocumentImportUnsupportedFileType", new Dictionary<string, string>
                        {
                            { "requestId", requestId },
                            { "endpoint", "/Documents/ImportDocument" },
                            { "fileName", file.FileName },
                            { "fileExtension", fileExtension },
                            { "contentType", contentType },
                            { "result", "BadRequest" }
                        });
                        return Results.BadRequest(new DocumentImportedResult() { DocumentId = string.Empty, 
                                                                                 MimeType = contentType,
                                                                                 Summary = $"{fileExtension} file is Unsupported file type" });
                    }

                    // Checking File Size: O byte/kb file not allowed
                    if (file == null || file.Length == 0)
                    {
                        // Trace: Empty file detected
                        logger.LogWarning("[{RequestId}] EMPTY FILE: File is null or has zero length. FileName: {FileName}",
                            requestId,
                            file?.FileName ?? "null");
                        
                        telemetryHelper.TrackEvent("DocumentImportEmptyFile", new Dictionary<string, string>
                        {
                            { "requestId", requestId },
                            { "endpoint", "/Documents/ImportDocument" },
                            { "fileName", file?.FileName ?? "unknown" },
                            { "result", "BadRequest" }
                        });
                        return Results.BadRequest(new DocumentImportedResult()
                        {
                            DocumentId = string.Empty,
                            MimeType = contentType,
                            Summary = "The file is empty and cannot be uploaded. Please select a valid file."
                        });
                    }

                    // Trace: Validation passed, beginning import
                    logger.LogInformation("[{RequestId}] File validation passed. Beginning document import. FileName: {FileName}, Extension: {FileExtension}, Size: {FileSize} bytes",
                        requestId,
                        file.FileName,
                        fileExtension,
                        file.Length);
                    
                    var result = await kernelMemory.ImportDocument(fileStream, file.FileName, contentType);
                    var duration = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: Document imported successfully
                    logger.LogInformation("[{RequestId}] Document imported successfully. Duration: {Duration}s, DocumentId: {DocumentId}, FileName: {FileName}, FileSize: {FileSize} bytes, MimeType: {MimeType}",
                        requestId,
                        duration.ToString("F2"),
                        result.DocumentId,
                        file.FileName,
                        file.Length,
                        result.MimeType ?? "unknown");

                    // Track successful document import with metrics
                    telemetryHelper.TrackEvent("DocumentImportSuccess", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/Documents/ImportDocument" },
                        { "documentId", result.DocumentId },
                        { "fileName", file.FileName },
                        { "fileExtension", fileExtension },
                        { "mimeType", result.MimeType ?? "unknown" },
                        { "fileSize", file.Length.ToString() },
                        { "duration", duration.ToString("F2") }
                    }, new Dictionary<string, double>
                    {
                        { "FileSizeBytes", file.Length },
                        { "UploadTimeSeconds", duration }
                    });

                    // Track large file uploads
                    if (file.Length > 10 * 1024 * 1024) // > 10MB
                    {
                        var fileSizeMB = file.Length / 1024.0 / 1024.0;
                        
                        // Trace: Large file upload
                        logger.LogInformation("[{RequestId}] LARGE FILE UPLOADED: Size: {FileSizeMB} MB, Duration: {Duration}s, DocumentId: {DocumentId}",
                            requestId,
                            fileSizeMB.ToString("F2"),
                            duration.ToString("F2"),
                            result.DocumentId);
                        
                        telemetryHelper.TrackEvent("DocumentImportLargeFile", new Dictionary<string, string>
                        {
                            { "requestId", requestId },
                            { "documentId", result.DocumentId },
                            { "fileSizeMB", (file.Length / 1024.0 / 1024.0).ToString("F2") },
                            { "duration", duration.ToString("F2") }
                        });
                    }
                    
                    // Trace: Upload performance check
                    if (duration > 30)
                    {
                        logger.LogWarning("[{RequestId}] SLOW UPLOAD: Document import took {Duration}s. FileSize: {FileSize} bytes, DocumentId: {DocumentId}",
                            requestId,
                            duration.ToString("F2"),
                            file.Length,
                            result.DocumentId);
                    }

                    // Set correlation ID for tracing
                    telemetryHelper.SetActivityTag("documentId", result.DocumentId);

                    //Return HTTP 202 with Location Header
                    //return Results($"/Documents/CheckProcessStatus/{result.DocumentId}", result);
                    // Add Document to the Repository

                    //Refresh the Cache
                    return Results.Ok<DocumentImportedResult>(result);
                }
                catch (IOException ex)
                {
                    var elapsedTime = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: IO error with details
                    logger.LogError(ex, "[{RequestId}] IO ERROR: File upload failed after {ElapsedTime}s. FileName: {FileName}, FileSize: {FileSize}, Message: {ErrorMessage}",
                        requestId,
                        elapsedTime.ToString("F2"),
                        file?.FileName ?? "unknown",
                        file?.Length ?? 0,
                        ex.Message);
                    
                    telemetryHelper.TrackEvent("DocumentImportIOError", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/Documents/ImportDocument" },
                        { "fileName", file?.FileName ?? "unknown" },
                        { "errorMessage", ex.Message }
                    });
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/Documents/ImportDocument" },
                        { "errorType", "IOException" }
                    });
                    throw;
                }
                catch (ArgumentException ex)
                {
                    var elapsedTime = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: Invalid argument
                    logger.LogError(ex, "[{RequestId}] INVALID ARGUMENT: Document upload failed after {ElapsedTime}s. FileName: {FileName}, ParamName: {ParamName}, Message: {ErrorMessage}",
                        requestId,
                        elapsedTime.ToString("F2"),
                        file?.FileName ?? "unknown",
                        ex.ParamName ?? "unknown",
                        ex.Message);
                    
                    telemetryHelper.TrackEvent("DocumentImportInvalidArgument", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/Documents/ImportDocument" },
                        { "fileName", file?.FileName ?? "unknown" },
                        { "errorMessage", ex.Message }
                    });
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/Documents/ImportDocument" },
                        { "errorType", "ArgumentException" }
                    });
                    throw;
                }
                catch (Exception ex)
                {
                    var elapsedTime = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: General error with full context
                    logger.LogError(ex, "[{RequestId}] DOCUMENT IMPORT FAILED: Unexpected error after {ElapsedTime}s. FileName: {FileName}, FileSize: {FileSize}, ErrorType: {ErrorType}, Message: {ErrorMessage}, StackTrace: {StackTrace}",
                        requestId,
                        elapsedTime.ToString("F2"),
                        file?.FileName ?? "unknown",
                        file?.Length ?? 0,
                        ex.GetType().Name,
                        ex.Message,
                        ex.StackTrace?.Substring(0, Math.Min(500, ex.StackTrace?.Length ?? 0)) ?? "N/A");
                    
                    telemetryHelper.TrackEvent("DocumentImportFailed", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/Documents/ImportDocument" },
                        { "fileName", file?.FileName ?? "unknown" },
                        { "errorType", ex.GetType().Name },
                        { "errorMessage", ex.Message },
                        { "innerException", ex.InnerException?.Message ?? "none" }
                    });
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/Documents/ImportDocument" },
                        { "errorType", ex.GetType().Name }
                    });
                    throw;
                }

            })
            .DisableAntiforgery();

            app.MapDelete("/Documents/{documentId}", async (HttpContext httpContext,
                                                            string documentId,
                                                            DPS.API.KernelMemory kernelMemory,
                                                            TelemetryHelper telemetryHelper,
                                                            ILogger<KernelMemory> logger) =>
            {
                // Generate unique request ID for tracking
                var requestId = httpContext.TraceIdentifier;
                telemetryHelper.SetActivityTag("requestId", requestId);
                var startTime = DateTimeOffset.UtcNow;
                var safeDocumentId = (documentId ?? "null").Replace("\r", string.Empty).Replace("\n", string.Empty);
                
                // Trace: Delete request received
                logger.LogInformation("[{RequestId}] Document delete request received. Endpoint: /Documents/{documentId}, DocumentId: {DocumentId}",
                    requestId, safeDocumentId);
                
                // Track delete started
                telemetryHelper.TrackEvent("DocumentDeleteStarted", new Dictionary<string, string>
                {
                    { "requestId", requestId },
                    { "endpoint", "/Documents/{documentId}" },
                    { "documentId", safeDocumentId }
                });
                
                try
                {
                    // Trace: Beginning delete operation
                    logger.LogDebug("[{RequestId}] Calling kernel memory to delete document: {DocumentId}",
                        requestId, safeDocumentId);
                    
                    await kernelMemory.DeleteDocument(documentId);
                    var duration = (DateTimeOffset.UtcNow - startTime).TotalSeconds;
                    
                    // Trace: Delete successful
                    logger.LogInformation("[{RequestId}] Document deleted successfully. Duration: {Duration}s, DocumentId: {DocumentId}",
                        requestId,
                        duration.ToString("F2"),
                        safeDocumentId);
                    
                    telemetryHelper.TrackEvent("DocumentDeleteSuccess", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/Documents/{documentId}" },
                        { "documentId", safeDocumentId },
                        { "duration", duration.ToString("F2") }
                    }, new Dictionary<string, double>
                    {
                        { "DeleteTimeSeconds", duration }
                    });
                    
                    return Results.Ok(new DocumentDeletedResult() { IsDeleted = true });
                }
                #pragma warning disable CA1031 // Must catch all to log and keep the process alive
                catch (Exception ex)
                {
                    var sanitizedDocumentId = (documentId ?? string.Empty)
                        .Replace(Environment.NewLine, string.Empty)
                        .Replace("\n", string.Empty)
                        .Replace("\r", string.Empty);
                    var elapsedTime = (DateTimeOffset.UtcNow - startTime).TotalSeconds;

                    // Trace: Delete failed with full context
                    logger.LogError(ex, "[{RequestId}] DOCUMENT DELETE FAILED: Error after {ElapsedTime}s. DocumentId: {DocumentId}, ErrorType: {ErrorType}, Message: {ErrorMessage}, StackTrace: {StackTrace}",
                        requestId,
                        elapsedTime.ToString("F2"),
                        sanitizedDocumentId,
                        ex.GetType().Name,
                        ex.Message,
                        ex.StackTrace?.Substring(0, Math.Min(500, ex.StackTrace?.Length ?? 0)) ?? "N/A");
                    
                    telemetryHelper.TrackEvent("DocumentDeleteFailed", new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/Documents/{documentId}" },
                        { "documentId", sanitizedDocumentId },
                        { "errorType", ex.GetType().Name },
                        { "errorMessage", ex.Message },
                        { "innerException", ex.InnerException?.Message ?? "none" }
                    });
                    telemetryHelper.TrackException(ex, new Dictionary<string, string>
                    {
                        { "requestId", requestId },
                        { "endpoint", "/Documents/{documentId}" },
                        { "documentId", sanitizedDocumentId },
                        { "errorType", ex.GetType().Name }
                    });
                    return Results.BadRequest(new DocumentDeletedResult() { IsDeleted = false });
                }
                #pragma warning restore CA1031
            })
            .DisableAntiforgery();

            app.MapGet("/Documents/{documentId}/CheckReadyStatus", async (string documentId,
                                                                          MemoryWebClient kmClient) =>
            {
                var result = await kmClient.IsDocumentReadyAsync(documentId);

                return Results.Ok(new DocumentReadyStatusResult() { IsReady = result });
            })
            .DisableAntiforgery();


            app.MapGet("/Documents/{documentId}/CheckProcessStatus/", async (string documentId,
                                                                             MemoryWebClient kmClient) =>
            {
                var status = await kmClient.GetDocumentStatusAsync(documentId);
                if (status == null)
                {
                    return Results.NotFound();
                }
                return Results.Ok(status);
            })
            .DisableAntiforgery();

            app.MapPost("/Documents/ImportText", async (string text,
                                                        MemoryWebClient kmClient) =>
            {
                try
                {
                    var documentId = await kmClient.ImportTextAsync(text);

                    return Results.Ok(new DocumentImportedResult() { DocumentId = documentId });
                }
                catch (IOException ex)
                {
                    // Log the exception
                    app.Logger.LogError(ex, "An error occurred while uploading the document.");
                    throw;
                }
                catch (Exception ex)
                {
                    // Log the exception
                    app.Logger.LogError(ex, "An unexpected error occurred.");
                    throw;
                }
            })
            .DisableAntiforgery();

            app.MapPost("/Documents/ImportWebPage", async (string url,
                                                           MemoryWebClient kmClient) =>
            {
                try
                {
                    // Implementation of the file upload
                    var documentId = await kmClient.ImportWebPageAsync(url);
                    return Results.Ok(new DocumentImportedResult() { DocumentId = documentId });
                }
                catch (IOException ex)
                {
                    // Log the exception
                    app.Logger.LogError(ex, "An error occurred while uploading the document.");
                    throw;
                }
                catch (Exception ex)
                {
                    // Log the exception
                    app.Logger.LogError(ex, "An unexpected error occurred.");
                    throw;
                }
            })
            .DisableAntiforgery();

            //Check the status of File Registration Process
            //TODO : Implement the SSE for the status of the document
            app.MapGet("/Documents/CheckStatus/{documentId}", async Task (HttpContext ctx,
                                                                          string documentId,
                                                                          MemoryWebClient kmClient, CancellationToken token) =>
            {
                ctx.Response.Headers.Append(HeaderNames.ContentType, "text/event-stream");

                //Creating While Loop with 10 mins timeout
                var timeout = DateTime.UtcNow.AddMinutes(10);
                var completeFlag = false;

                var status = await kmClient.GetDocumentStatusAsync(documentId);

                while (DateTime.UtcNow < timeout)
                {
                    token.ThrowIfCancellationRequested();

                    //if status is null then return 404 with exit the loop
                    if (status == null)
                    {
                        ctx.Response.StatusCode = 404;
                        return;
                    }

                    if (status.RemainingSteps.Count == 0)
                    {
                        completeFlag = true;
                        break;
                    }
                    var totalSteps = status.Steps.Count;
                    var statusObject = new
                    {
                        progress_percentage = status.CompletedSteps.Count / totalSteps * 100,
                        completed = status.Completed
                    };

                    await ctx.Response.WriteAsync($"{JsonSerializer.Serialize(statusObject)}", cancellationToken: token);
                    await ctx.Response.Body.FlushAsync(token);

                    await Task.Delay(new TimeSpan(0, 0, 5));

                    status = await kmClient.GetDocumentStatusAsync(documentId);
                }

                await ctx.Response.CompleteAsync();
            })
            .DisableAntiforgery();


            app.MapPost("/Documents/Search", async (MemoryWebClient kmClient,
                                                    SearchParameter searchParameter) =>
            {
                var searchResult = await kmClient.SearchAsync(query: searchParameter.query,
                                                              filter: searchParameter.MemoryFilter,
                                                              filters: searchParameter.MemoryFilters,
                                                              minRelevance: searchParameter.minRelevance,
                                                              limit: searchParameter.limit,
                                                              context: searchParameter.Context);

                if (searchResult == null)
                {
                    return Results.NoContent();
                }

                return Results.Ok(searchResult);
            })
            .DisableAntiforgery();


            app.MapPost("/Documents/Ask", async (MemoryWebClient kmClient,
                                                 AskParameter askParameter) =>

            {
                //create Memory Filter
                var memoryFilters = new List<MemoryFilter>();
                askParameter.documents.ToList().ForEach(docId => memoryFilters.Add(new MemoryFilter().ByDocument(docId)));

                var answer = await kmClient.AskAsync(question: askParameter.question,
                                                     filters: memoryFilters);
                if (answer == null)
                {
                    return Results.NoContent();
                }
                return Results.Ok(answer);
            })
            .DisableAntiforgery();
        }
    }
}
