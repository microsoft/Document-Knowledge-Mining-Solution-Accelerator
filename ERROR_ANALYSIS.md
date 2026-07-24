# Root Cause Analysis: 500 Error on /ask Endpoint

## Summary
**YES, the 500 error IS DIRECTLY CAUSED by the previous fix!**

## The Problem

### Deployment Configuration
- **Deployment Name**: `gpt-5-mini` (from infra/main.bicep line 39)
- **Model Name**: `gpt-5-mini`

### The Bug in Previous Fix
In `AzureOpenAITextGenerator.cs`, the code checks:
```csharp
var isGpt5Deployment = this._deployment.StartsWith("gpt-5", StringComparison.OrdinalIgnoreCase);
```

When deployment is `gpt-5-mini`, this evaluates to `true`.

For GPT-5, the code skips setting:
- Temperature
- NucleusSamplingFactor  
- FrequencyPenalty
- PresencePenalty

### Why This Causes 500 Error

**GPT-5 Models DO NOT Support Streaming with Chat API**

The current code attempts to use streaming:
```csharp
StreamingResponse<StreamingChatCompletionsUpdate>? response = 
    await this._client.GetChatCompletionsStreamingAsync(openaiOptions, cancellationToken)
```

But GPT-5 models do NOT support streaming responses in Azure OpenAI. When the service tries to call the streaming endpoint, Azure OpenAI returns an HTTP 500 error.

### Additionally: Temperature Parameter Issue
Even if streaming worked, GPT-5 requires:
- Temperature: MUST be exactly 1.0 for GPT-5 models
- Cannot use other sampling parameters with GPT-5

The previous fix changed Temperature to 1 in ImageContextDecoder and KeywordExtractingHandler (for processing), but the GenerateAnswer method doesn't have these parameters set for GPT-5!

## Solution

Need to fix AzureOpenAITextGenerator.cs to:
1. Use non-streaming API for GPT-5 models (which support Chat Completions but NOT streaming)
2. Set Temperature to 1.0 for GPT-5
3. Ensure the response is properly parsed
