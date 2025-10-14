using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Azure;
using Azure.AI.DocumentIntelligence;
using Microsoft.Extensions.Logging;
using Microsoft.KernelMemory.DataFormats;
using Microsoft.KernelMemory.DataFormats.Pdf;
using Microsoft.KernelMemory.Diagnostics;
using Microsoft.KernelMemory.Pipeline;

namespace Microsoft.GS.DPS.Decoders
{
    public class CustomDocIntelPdfDecoder(DocumentIntelligenceClient client, ILoggerFactory? loggerFactory = null) : IContentDecoder
    {
        private readonly DocumentIntelligenceClient _client = client;
        private readonly ILogger<CustomDocIntelPdfDecoder> _log = (loggerFactory ?? DefaultLogger.Factory).CreateLogger<CustomDocIntelPdfDecoder>();

        public async Task<FileContent> DecodeAsync(string filename, CancellationToken cancellationToken = default)
        {
            using var stream = File.OpenRead(filename);
            return await DecodeAsync(stream, cancellationToken).ConfigureAwait(false);
        }

        public async Task<FileContent> DecodeAsync(Stream data, CancellationToken cancellationToken = default)
        {
            using var memoryStream = new MemoryStream();
            await data.CopyToAsync(memoryStream, cancellationToken).ConfigureAwait(true);
            BinaryData binaryData = new(memoryStream.ToArray());

            return await this.DecodeAsync(binaryData, cancellationToken).ConfigureAwait(true);
        }

        public async Task<FileContent> DecodeAsync(BinaryData data, CancellationToken cancellationToken = default)
        {
            var analyzeDocumentOptions = new AnalyzeDocumentOptions("prebuilt-layout", data)
            {
                OutputContentFormat = DocumentContentFormat.Text
            };
            var result = new FileContent(MimeTypes.PlainText);

            this._log.LogDebug("Extracting text from PDF file");

            var analysis = await _client
                .AnalyzeDocumentAsync(
                    WaitUntil.Completed,
                    analyzeDocumentOptions,
                    cancellationToken)
                .ConfigureAwait(false);

            for (var i = 0; i < analysis.Value.Paragraphs.Count; i++)
            {
                var paragraph = analysis.Value.Paragraphs[i];
                result.Sections.Add(new(paragraph.Content.Trim(), i + 1, Chunk.Meta(sentencesAreComplete: true)));
            }

            return result;
        }

        public bool SupportsMimeType(string mimeType)
        {
            return mimeType.Equals(MimeTypes.Pdf);
        }
    }
}
