using System;
using System.Threading.Tasks;
using Azure.Core;
using Azure.Identity;
namespace Helpers;

public static class azure_credential_utils
{
    public static TokenCredential GetAzureCredential(string clientId = null)
    {
        var env = Environment.GetEnvironmentVariable("APP_ENV") ?? "prod";

        if (string.Equals(env, "dev", StringComparison.OrdinalIgnoreCase))
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

    public static Task<TokenCredential> GetAzureCredentialAsync(string clientId = null)
    {
        return Task.FromResult(GetAzureCredential(clientId));
    }
}
