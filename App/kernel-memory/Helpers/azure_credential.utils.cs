// Copyright (c) Microsoft. All rights reserved.
using System;
using System.Reflection.PortableExecutable;
using System.Threading.Tasks;
using Azure.Core;
using Azure.Identity;
namespace Helpers;

public class azure_credential_utils
{
    public static TokenCredential GetAzureCredential(string appEnv = "prod", string clientId = null)
    {
        //var env = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";

        if (string.Equals(appEnv, "dev", StringComparison.OrdinalIgnoreCase))
        {
            return new DefaultAzureCredential(); // For local development
        }
        else
        {
            return clientId != null
                ? new ManagedIdentityCredential(clientId)
                : new ManagedIdentityCredential();
        }
    }

    public static Task<TokenCredential> GetAzureCredentialAsync(string appEnv = "prod", string clientId = null)
    {
        return Task.FromResult(GetAzureCredential(appEnv, clientId));
    }
}
