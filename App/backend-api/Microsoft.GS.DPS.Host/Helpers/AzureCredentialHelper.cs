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
                return new DefaultAzureCredential(); // CodeQL [SM05139] Okay use of DefaultAzureCredential as it is only used in development
            }
            else
            {
                return clientId != null
                    ? new ManagedIdentityCredential(clientId)
                    : new ManagedIdentityCredential();
            }
        }
    }
}