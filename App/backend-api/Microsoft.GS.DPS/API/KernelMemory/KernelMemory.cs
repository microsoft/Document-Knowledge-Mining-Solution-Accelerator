using Microsoft.Extensions.Logging;
using Microsoft.GS.DPS.Images;
using Microsoft.GS.DPS.Model.KernelMemory;
using Microsoft.GS.DPS.Storage.Components;
using Microsoft.GS.DPS.Storage.Document;
using Microsoft.KernelMemory;
using Microsoft.KernelMemory.Context;
using Microsoft.KernelMemory.Pipeline;
using MongoDB.Bson;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Document = Microsoft.GS.DPS.Storage.Document.Entities.Document;
using Microsoft.GS.DPS.API.UserInterface;
using Microsoft.GS.DPS.Storage.AISearch;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace Microsoft.GS.DPS.API
{
    public class KernelMemory
    {
        private readonly MemoryWebClient _kmClient;
        private readonly DocumentRepository _documentRepository;
        private readonly DataCacheManager _dataCache;
        private readonly TagUpdater _tagUpdator;
        private readonly ILogger<KernelMemory>? _logger;
        private readonly ConcurrentDictionary<string, Lazy<Task<DocumentImportedResult>>> _documentImports = new();
        private static readonly string keywordExtractorPrompt = "";
        private static readonly TimeSpan importLeaseDuration = TimeSpan.FromMinutes(10);
        private static readonly TimeSpan importLeaseRenewalInterval = TimeSpan.FromMinutes(1);
        private static readonly TimeSpan importLeaseWaitTimeout = TimeSpan.FromMinutes(70);

        static KernelMemory()
        {
            //Set Location of the System Prompt under running Assembly directory location.
            var assemblyLocation = Assembly.GetExecutingAssembly().Location;
            var assemblyDirectory = System.IO.Path.GetDirectoryName(assemblyLocation);
            // binding assembly directory with file path (Prompts/KeywordExtract_SystemPrompt.txt)
            var systemPromptFilePath = System.IO.Path.Join(assemblyDirectory, "Prompts", "KeywordExtract_SystemPrompt.txt");
            KernelMemory.keywordExtractorPrompt = System.IO.File.ReadAllText(systemPromptFilePath);
        }

        public KernelMemory(MemoryWebClient kmClient, DocumentRepository documentRepository, DataCacheManager dataCache, TagUpdater tagUpdator, ILogger<KernelMemory>? logger = null)
        {
            _kmClient = kmClient;
            _documentRepository = documentRepository;
            _dataCache = dataCache;
            _tagUpdator = tagUpdator;
            _logger = logger;
        }

        public async Task<DocumentImportedResult> ImportDocument(Stream documentStream,
                                                                 string fileName, 
                                                                 string contentType)
        {
            using var bufferedStream = documentStream.CanSeek ? null : CreateTemporaryFileStream();
            Stream importStream = documentStream;

            if (bufferedStream != null)
            {
                await documentStream.CopyToAsync(bufferedStream);
                importStream = bufferedStream;
            }

            importStream.Position = 0;
            var contentHash = await SHA256.HashDataAsync(importStream);
            importStream.Position = 0;
            var documentId = Convert.ToHexString(contentHash).ToLowerInvariant();

            var documentImport = _documentImports.GetOrAdd(
                documentId,
                _ => new Lazy<Task<DocumentImportedResult>>(
                    () => ImportDocumentCore(importStream, fileName, contentType, documentId),
                    LazyThreadSafetyMode.ExecutionAndPublication));

            try
            {
                return await documentImport.Value;
            }
            finally
            {
                ((ICollection<KeyValuePair<string, Lazy<Task<DocumentImportedResult>>>>)_documentImports)
                    .Remove(new KeyValuePair<string, Lazy<Task<DocumentImportedResult>>>(documentId, documentImport));
            }
        }

        private static FileStream CreateTemporaryFileStream()
        {
            var temporaryFilePath = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
            return new FileStream(
                temporaryFilePath,
                FileMode.CreateNew,
                FileAccess.ReadWrite,
                FileShare.None,
                bufferSize: 81920,
                FileOptions.Asynchronous | FileOptions.SequentialScan | FileOptions.DeleteOnClose);
        }

        private async Task<DocumentImportedResult> ImportDocumentCore(Stream importStream,
                                                                       string fileName,
                                                                       string contentType,
                                                                       string documentId)
        {
            var existingDocument = await _documentRepository.FindByDocumentIdAsync(documentId);
            if (existingDocument != null)
            {
                return ToImportedResult(existingDocument);
            }

            var leaseOwnerId = Guid.NewGuid().ToString("N");
            var leaseWaitDeadline = DateTime.UtcNow.Add(importLeaseWaitTimeout);

            while (!await _documentRepository.TryAcquireImportLeaseAsync(
                       documentId,
                       leaseOwnerId,
                       DateTime.UtcNow.Add(importLeaseDuration)))
            {
                if (DateTime.UtcNow >= leaseWaitDeadline)
                {
                    throw new TimeoutException("Timed out waiting for another import of this document to complete.");
                }

                await Task.Delay(TimeSpan.FromSeconds(2));
                existingDocument = await _documentRepository.FindByDocumentIdAsync(documentId);
                if (existingDocument != null)
                {
                    return ToImportedResult(existingDocument);
                }
            }

            using var leaseRenewalCancellation = new CancellationTokenSource();
            var leaseRenewalTask = RenewImportLeaseAsync(documentId, leaseOwnerId, leaseRenewalCancellation.Token);

            try
            {
                existingDocument = await _documentRepository.FindByDocumentIdAsync(documentId);
                if (existingDocument != null)
                {
                    return ToImportedResult(existingDocument);
                }

                // Implementation of the file upload
                await _kmClient.ImportDocumentAsync(importStream, fileName, documentId: documentId, steps: [
                                    Constants.PipelineStepsExtract,
                                    "keyword_extract",
                                    Constants.PipelineStepsSummarize,
                                    Constants.PipelineStepsPartition,
                                    Constants.PipelineStepsGenEmbeddings,
                                    Constants.PipelineStepsSaveRecords
                            ]);
            // Check the processing status of the document with Timeout 3mins
            var startTime = DateTime.Now;
            var elapsedTime = DateTime.Now - startTime;

            // Set Timeout 60 mins - Document Processing Time
            var timeout = TimeSpan.FromMinutes(60);

            while (true)
            {
                var isReady = await _kmClient.IsDocumentReadyAsync(documentId);
                if (isReady) break;

                await Task.Delay(5000);
                elapsedTime = DateTime.Now - startTime;
                if (elapsedTime > timeout)
                {
                    throw new TimeoutException("Document processing timeout");
                }
            }

            var importedResult = new DocumentImportedResult
            {
                DocumentId = documentId,
                ImportedTime = DateTime.UtcNow,
                MimeType = contentType,
                FileName = fileName,
                ProcessingTime = elapsedTime,
                Keywords = await getKeywords(documentId, fileName),
                Summary = await getSummary(documentId, fileName)
            };


            // Save the document to the repository
            Document document = new Document
            {
                id = new Guid(Convert.FromHexString(documentId[..32])),
                DocumentId = documentId,
                FileName = fileName,
                ImportedTime = importedResult.ImportedTime,
                MimeType = contentType,
                ProcessingTime = importedResult.ProcessingTime,
                Summary = importedResult.Summary,
                Keywords = importedResult.Keywords
            };
            document.__partitionkey = CosmosDBEntityBase.GetKey(document.id, 9999);

                await _documentRepository.RegisterAsync(document);

                //Cache Refresh
                _dataCache.ManualRefresh();

                return importedResult;
            }
            finally
            {
                leaseRenewalCancellation.Cancel();

                try
                {
                    await leaseRenewalTask;
                }
                catch (OperationCanceledException) when (leaseRenewalCancellation.IsCancellationRequested)
                {
                }
                catch (Exception exception)
                {
                    _logger?.LogWarning(exception, "Failed to renew the import lease for document {DocumentId}", documentId);
                }

                try
                {
                    await _documentRepository.ReleaseImportLeaseAsync(documentId, leaseOwnerId);
                }
                catch (Exception exception)
                {
                    _logger?.LogWarning(exception, "Failed to release the import lease for document {DocumentId}", documentId);
                }
            }
        }

        private async Task RenewImportLeaseAsync(string documentId, string ownerId, CancellationToken cancellationToken)
        {
            while (true)
            {
                await Task.Delay(importLeaseRenewalInterval, cancellationToken);
                var renewed = await _documentRepository.RenewImportLeaseAsync(
                    documentId,
                    ownerId,
                    DateTime.UtcNow.Add(importLeaseDuration));

                if (!renewed)
                {
                    throw new InvalidOperationException($"The import lease for document {documentId} is no longer owned by this process.");
                }
            }
        }

        private static DocumentImportedResult ToImportedResult(Document document)
        {
            return new DocumentImportedResult
            {
                DocumentId = document.DocumentId,
                ImportedTime = document.ImportedTime,
                MimeType = document.MimeType,
                FileName = document.FileName,
                ProcessingTime = document.ProcessingTime,
                Keywords = document.Keywords,
                Summary = document.Summary
            };
        }

        public async Task<bool> DeleteDocument(string documentId)
        {
            if (string.IsNullOrEmpty(documentId))
            {
                throw new ArgumentException("DocumentId is required");
            }

            // DeleteAsync the document from the repository
            Document registeredDocument = await _documentRepository.FindByDocumentIdAsync(documentId);
            //var document = registeredDocument.Results.FirstOrDefault();
            if (registeredDocument != null)  await _documentRepository.DeleteAsync(registeredDocument.id);
            
            // DeleteAsync the document from the Kernel Memory
            await _kmClient.DeleteDocumentAsync(documentId);

            return true;
        }


        private async Task<string> getSummary(string documentId, string fileName)
        {
            // Summary file
            var summaryFileName = $"{fileName}.summarize.0.txt";
            // Download Summary file
            var summaryFile = await _kmClient.ExportFileAsync(documentId, summaryFileName);
            var summaryFileStream = await summaryFile.GetStreamAsync();
            // Read Stream to string
            using var reader = new StreamReader(summaryFileStream);
            return await reader.ReadToEndAsync();
        }


        private async Task<Dictionary<string, string>?> getKeywords(string documentId, string fileName)
        {
            // Get Keyword file
            var keywordFileName = $"{fileName}.tags.json";
            // Download Keyword file
            var keywordFile = await _kmClient.ExportFileAsync(documentId, keywordFileName);
            var keywordFileStream = await keywordFile.GetStreamAsync();
            // Read Stream to string
            string? keywordContent;
            using (var reader = new StreamReader(keywordFileStream))
            {
                keywordContent = await reader.ReadToEndAsync();
            }

            if (string.IsNullOrEmpty(keywordContent))
            {
                return new Dictionary<string,string>();
            }else
            {
                // Read the keyword file then parse to KeyValuePair<string, string[]>
                try
                {
                    var result =  JsonSerializer.Deserialize<List<Dictionary<string, List<string>>>>(keywordContent);

                    if (result.Count == 0)
                    {
                        //Just in case the document is large, get keywords via KM.
                        var answer = await _kmClient.AskAsync(question: KernelMemory.keywordExtractorPrompt, filters: new List<MemoryFilter> { new MemoryFilter().ByDocument(documentId) });
                        result = JsonSerializer.Deserialize<List<Dictionary<string, List<string>>>>(answer.Result);
                        var listKeyValueString = new List<string>();
                        foreach (var dict in result)
                        {
                            foreach (var kvp in dict)
                            {
                                foreach (var value in kvp.Value)
                                {
                                    listKeyValueString.Add($"{kvp.Key.Trim()}:{value.Trim()}");
                                }
                            }
                        }
                        //Update Azure Search tags collection.
                        await _tagUpdator.UpdateTags(documentId, listKeyValueString);
                    }

                    //convert result to Dictionary<string, string>
                    var keywordDict = new Dictionary<string, string>();

                    foreach (var item in result)
                    {
                        foreach (var key in item.Keys)
                        {
                            keywordDict.Add(key, string.Join(", ", item[key]));
                        }
                    }

                    return keywordDict;
                }
                catch (JsonException ex)
                {
                    _logger?.LogWarning(ex, "Failed to parse keyword JSON for document {DocumentId} ({FileName}); returning empty keyword set.", documentId, fileName);
                    return new Dictionary<string, string>();
                }
                #pragma warning disable CA1031 // LLM keyword-extraction output may be malformed; fall back to empty result rather than failing the import
                catch (Exception ex)
                {
                    _logger?.LogWarning(ex, "Failed to extract keywords for document {DocumentId} ({FileName}); returning empty keyword set.", documentId, fileName);
                    return new Dictionary<string, string>();
                }
                #pragma warning restore CA1031
            }
        }

        public async Task<MemoryAnswer> Ask(string question, string[] documents, ICollection<MemoryFilter>? filters = null, RequestContext? context = null)
        {
            ICollection<MemoryFilter>? memFilters = null;

            if (documents.Length > 0)
            {
                memFilters = new List<MemoryFilter>();
                foreach (var documentId in documents)
                {
                    memFilters.Add(new MemoryFilter().ByDocument(documentId));
                }
            }

            var answer = await _kmClient.AskAsync(question: question, filters: memFilters, context: context, minRelevance: 0.012);
            return answer;
        }

        public async Task<StreamableFileContent> ExportFile(string documentId, string fileName)
        {
            var fileContent = await _kmClient.ExportFileAsync(documentId, fileName);
            return fileContent;
        }

        
    }
}
