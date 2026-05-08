using System;
using System.Threading.Tasks;
using Azure.Core;
using Azure.Identity;

namespace Microsoft.GS.DPSHost.Helpers
{
    /// <summary>
    /// The Azure Credential Helper class
    /// </summary>
    public static class AzureCredentialHelper
    {
        /// <summary>
        /// Get the Azure Credentials based on the environment type
        /// </summary>
        /// <param name="clientId">The client Id in case of User assigned Managed identity</param>
        /// <returns>The Credential Object</returns>
        public static TokenCredential GetAzureCredential(string? clientId = null)
        {
            var env = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";

            if (string.Equals(env, "Development", StringComparison.OrdinalIgnoreCase))
            {
                // Include ManagedIdentityCredential first so the same image works in AKS
                // (where ASPNETCORE_ENVIRONMENT is Development to load appsettings.Development.json
                // for the App Configuration endpoint) without falling back to dev-only credentials
                // that don't exist inside the pod.
                return new ChainedTokenCredential(
                    clientId != null ? new ManagedIdentityCredential(clientId) : new ManagedIdentityCredential(),
                    new VisualStudioCredential(),
                    new AzureCliCredential(),
                    new AzurePowerShellCredential(),
                    new AzureDeveloperCliCredential());
            }

            return clientId != null
                ? new ManagedIdentityCredential(clientId)
                : new ManagedIdentityCredential();
        }
    }
}