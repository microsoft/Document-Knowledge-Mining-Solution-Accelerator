// Copyright (c) Microsoft. All rights reserved.

using System;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.Net.Http;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;
using Azure;
using Azure.AI.OpenAI;
using Azure.Core.Pipeline;
using Azure.Identity;
using Microsoft.Extensions.Logging;
using Microsoft.KernelMemory.AI.AzureOpenAI.Internals;
using Microsoft.KernelMemory.AI.OpenAI;
using Microsoft.KernelMemory.Diagnostics;

namespace Microsoft.KernelMemory.AI.AzureOpenAI;

[Experimental("KMEXP01")]
public sealed class AzureOpenAITextGenerator : ITextGenerator
{
    private readonly ITextTokenizer _textTokenizer;
    private readonly OpenAIClient _client;
    private readonly ILogger<AzureOpenAITextGenerator> _log;
    private readonly bool _useTextCompletionProtocol;
    private readonly string _deployment;

    public AzureOpenAITextGenerator(
        AzureOpenAIConfig config,
        ITextTokenizer? textTokenizer = null,
        ILoggerFactory? loggerFactory = null,
        HttpClient? httpClient = null)
    {
        this._log = (loggerFactory ?? DefaultLogger.Factory).CreateLogger<AzureOpenAITextGenerator>();

        if (textTokenizer == null)
        {
            this._log.LogWarning(
                "Tokenizer not specified, will use {0}. The token count might be incorrect, causing unexpected errors",
                nameof(GPT4Tokenizer));
            textTokenizer = new GPT4Tokenizer();
        }

        this._textTokenizer = textTokenizer;

        if (string.IsNullOrEmpty(config.Endpoint))
        {
            throw new ConfigurationException($"Azure OpenAI: {config.Endpoint} is empty");
        }

        if (string.IsNullOrEmpty(config.Deployment))
        {
            throw new ConfigurationException($"Azure OpenAI: {config.Deployment} is empty");
        }

        this._useTextCompletionProtocol = config.APIType == AzureOpenAIConfig.APITypes.TextCompletion;
        this._deployment = config.Deployment;
        this.MaxTokenTotal = config.MaxTokenTotal;

        OpenAIClientOptions options = new()
        {
            RetryPolicy = new RetryPolicy(maxRetries: Math.Max(0, config.MaxRetries), new SequentialDelayStrategy()),
            Diagnostics =
            {
                IsTelemetryEnabled = Telemetry.IsTelemetryEnabled,
                ApplicationId = Telemetry.HttpUserAgent,
            }
        };

        if (httpClient is not null)
        {
            options.Transport = new HttpClientTransport(httpClient);
        }

        switch (config.Auth)
        {
            case AzureOpenAIConfig.AuthTypes.AzureIdentity:
                this._client = new OpenAIClient(new Uri(config.Endpoint), new DefaultAzureCredential(), options);
                break;

            case AzureOpenAIConfig.AuthTypes.ManualTokenCredential:
                this._client = new OpenAIClient(new Uri(config.Endpoint), config.GetTokenCredential(), options);
                break;

            case AzureOpenAIConfig.AuthTypes.APIKey:
                if (string.IsNullOrEmpty(config.APIKey))
                {
                    throw new ConfigurationException($"Azure OpenAI: {config.APIKey} is empty");
                }

                this._client = new OpenAIClient(new Uri(config.Endpoint), new AzureKeyCredential(config.APIKey), options);
                break;

            default:
                throw new ConfigurationException($"Azure OpenAI: authentication type '{config.Auth:G}' is not supported");
        }
    }

    /// <inheritdoc/>
    public int MaxTokenTotal { get; }

    /// <inheritdoc/>
    public int CountTokens(string text)
    {
        return this._textTokenizer.CountTokens(text);
    }

    /// <inheritdoc/>
    public IReadOnlyList<string> GetTokens(string text)
    {
        return this._textTokenizer.GetTokens(text);
    }

    /// <inheritdoc/>
    public async IAsyncEnumerable<string> GenerateTextAsync(
        string prompt,
        TextGenerationOptions options,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        if (this._useTextCompletionProtocol)
        {
            this._log.LogTrace("Sending text generation request, deployment '{0}'", this._deployment);

            var isGpt5Deployment = this._deployment.StartsWith("gpt-5", StringComparison.OrdinalIgnoreCase);

            var openaiOptions = new CompletionsOptions
            {
                DeploymentName = this._deployment,
                ChoicesPerPrompt = 1,
            };

            // GPT-5 deployments use max_completion_tokens instead of max_tokens
            // and require Temperature = 1.0 (default), rejecting other legacy sampling parameters.
            // GPT-5 also does NOT support streaming.
            if (!isGpt5Deployment)
            {
                openaiOptions.MaxTokens = options.MaxTokens;
                openaiOptions.Temperature = (float)options.Temperature;
                openaiOptions.NucleusSamplingFactor = (float)options.NucleusSampling;
                openaiOptions.FrequencyPenalty = (float)options.FrequencyPenalty;
                openaiOptions.PresencePenalty = (float)options.PresencePenalty;

                if (options.TokenSelectionBiases is { Count: > 0 })
                {
                    foreach (var (token, bias) in options.TokenSelectionBiases) { openaiOptions.TokenSelectionBiases.Add(token, (int)bias); }
                }
            }
            // For GPT-5: Don't set Temperature or sampling parameters - use API defaults
            
            if (options.StopSequences is { Count: > 0 })
            {
                foreach (var s in options.StopSequences) { openaiOptions.StopSequences.Add(s); }
            }

            if (isGpt5Deployment)
            {
                // Use non-streaming API for GPT-5
                Response<Completions>? response = await this._client.GetCompletionsAsync(openaiOptions, cancellationToken).ConfigureAwait(false);
                if (response?.Value?.Choices.Count > 0)
                {
                    yield return response.Value.Choices[0].Text;
                }
            }
            else
            {
                // Use streaming API for non-GPT-5 models
                StreamingResponse<Completions>? response = await this._client.GetCompletionsStreamingAsync(openaiOptions, cancellationToken).ConfigureAwait(false);
                await foreach (Completions? completions in response.EnumerateValues().WithCancellation(cancellationToken).ConfigureAwait(false))
                {
                    foreach (Choice? choice in completions.Choices)
                    {
                        yield return choice.Text;
                    }
                }
            }
        }
        else
        {
            this._log.LogTrace("Sending chat message generation request, deployment '{0}'", this._deployment);

            var isGpt5Deployment = this._deployment.StartsWith("gpt-5", StringComparison.OrdinalIgnoreCase);

            var openaiOptions = new ChatCompletionsOptions
            {
                DeploymentName = this._deployment,
                // ChoiceCount = 1,
            };

            // GPT-5 deployments use max_completion_tokens instead of max_tokens
            // and require Temperature = 1.0 (default), rejecting other legacy sampling parameters.
            // GPT-5 also does NOT support streaming, so we use non-streaming API for GPT-5.
            if (!isGpt5Deployment)
            {
                openaiOptions.MaxTokens = options.MaxTokens;
                openaiOptions.Temperature = (float)options.Temperature;
                openaiOptions.NucleusSamplingFactor = (float)options.NucleusSampling;
                openaiOptions.FrequencyPenalty = (float)options.FrequencyPenalty;
                openaiOptions.PresencePenalty = (float)options.PresencePenalty;
            }
            // For GPT-5: Don't set Temperature or sampling parameters - use API defaults

            if (options.StopSequences is { Count: > 0 })
            {
                foreach (var s in options.StopSequences) { openaiOptions.StopSequences.Add(s); }
            }

            if (options.TokenSelectionBiases is { Count: > 0 })
            {
                foreach (var (token, bias) in options.TokenSelectionBiases) { openaiOptions.TokenSelectionBiases.Add(token, (int)bias); }
            }

            openaiOptions.Messages.Add(new ChatRequestSystemMessage(prompt));

            // GPT-5 does not support streaming - use non-streaming API
            if (isGpt5Deployment)
            {
                Response<ChatCompletions>? response = await this._client.GetChatCompletionsAsync(openaiOptions, cancellationToken).ConfigureAwait(false);
                if (response?.Value?.Choices.Count > 0)
                {
                    yield return response.Value.Choices[0].Message.Content;
                }
            }
            else
            {
                StreamingResponse<StreamingChatCompletionsUpdate>? response = await this._client.GetChatCompletionsStreamingAsync(openaiOptions, cancellationToken).ConfigureAwait(false);
                await foreach (StreamingChatCompletionsUpdate? update in response.EnumerateValues().WithCancellation(cancellationToken).ConfigureAwait(false))
                {
                    yield return update.ContentUpdate;
                }
            }
        }
    }
}
