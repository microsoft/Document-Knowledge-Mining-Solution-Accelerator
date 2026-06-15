// ============================================================================
// main.bicep — Deployment Router
// Description: Routes deployment to the appropriate infrastructure flavor:
//   - 'bicep'   → Vanilla Microsoft.* modules           (infra/bicep/main.bicep)
//   - 'avm'     → AVM-based modules (non-WAF)           (infra/avm/main.bicep)
//   - 'avm-waf' → AVM-based modules, WAF-aligned        (infra/avm/main.bicep)
//                 (monitoring, private networking, scalability, redundancy
//                 are enabled via main.waf.parameters.json)
//
// Both flavors expose identical parameters and outputs. Selection is
// runtime-driven via the `deploymentFlavor` parameter so a single azd
// environment can switch flavors without changing source.
// ============================================================================
targetScope = 'resourceGroup'

// ============================================================================
// Routing Parameter
// ============================================================================

@allowed(['bicep', 'avm', 'avm-waf'])
@description('Required. Deployment flavor: \'bicep\' (vanilla Microsoft.* modules, public-endpoint-only), \'avm\' (Azure Verified Modules, non-WAF), or \'avm-waf\' (AVM, WAF-aligned with private networking, scalability, redundancy).')
param deploymentFlavor string = 'avm'

// ============================================================================
// Parameters — Core (shared across all flavors)
// ============================================================================

@minLength(3)
@maxLength(20)
@description('Required. A unique prefix for all resources in this deployment. This should be 3-20 characters long.')
param solutionName string = 'kmgs'

@description('Optional. Azure location for the solution. If not provided, defaults to the resource group location.')
param location string = ''

@maxLength(5)
@description('Optional. A unique token for the solution. Used to ensure resource names are unique for global resources.')
param solutionUniqueText string = substring(uniqueString(subscription().id, resourceGroup().name, solutionName), 0, 5)

// ============================================================================
// Parameters — AI / Model configuration
// ============================================================================

@minLength(1)
@allowed(['Standard', 'GlobalStandard'])
@description('Optional. GPT model deployment type.')
param deploymentType string = 'GlobalStandard'

@minLength(1)
@allowed(['gpt-4.1-mini'])
@description('Optional. Name of the GPT model to deploy.')
param gptModelName string = 'gpt-4.1-mini'

@description('Optional. Version of the GPT model to deploy.')
param gptModelVersion string = '2025-04-14'

@minValue(10)
@description('Optional. Capacity of the GPT model deployment.')
param gptDeploymentCapacity int = 100

@minLength(1)
@allowed(['text-embedding-3-large'])
@description('Optional. Name of the Text Embedding model to deploy.')
param embeddingModelName string = 'text-embedding-3-large'

@description('Optional. Version of the Text Embedding model to deploy.')
param embeddingModelVersion string = '1'

@minValue(10)
@description('Optional. Capacity of the Text Embedding model deployment.')
param embeddingDeploymentCapacity int = 100

@metadata({
  azd: {
    type: 'location'
    usageName: [
      'OpenAI.GlobalStandard.gpt4.1-mini,150'
      'OpenAI.GlobalStandard.text-embedding-3-large,100'
    ]
  }
})
@description('Required. Location for AI Foundry deployment. Where the AI Foundry / OpenAI resources will be deployed.')
param azureAiServiceLocation string

// ============================================================================
// Parameters — Existing resources
// ============================================================================

@description('Optional. Existing Log Analytics Workspace Resource ID. If provided, monitoring will use this workspace instead of creating a new one.')
param existingLogAnalyticsWorkspaceId string = ''

// ============================================================================
// Parameters — Jumpbox VM (only used when enablePrivateNetworking is true)
// ============================================================================

@description('Optional. Admin username for the Jumpbox Virtual Machine. Set when enablePrivateNetworking is true.')
@secure()
param vmAdminUsername string?

@description('Optional. Admin password for the Jumpbox Virtual Machine. Set when enablePrivateNetworking is true.')
@secure()
param vmAdminPassword string?

@description('Optional. Size of the Jumpbox Virtual Machine when created. Set when enablePrivateNetworking is true.')
param vmSize string = 'Standard_D2s_v5'

// ============================================================================
// Parameters — Tags / Telemetry
// ============================================================================

@description('Optional. The tags to apply to all deployed Azure resources.')
param tags object = {}

@description('Optional. Enable/Disable usage telemetry for AVM modules. Forwarded to the AVM flavor; the bicep flavor accepts it for signature parity but has no telemetry hooks. Defaults to true.')
param enableTelemetry bool = true

// ============================================================================
// Parameters — WAF feature toggles
// ============================================================================

@description('Optional. Enable private networking for applicable resources, aligned with the WAF recommendations. Only takes effect when deploymentFlavor=\'avm\' or \'avm-waf\'; the bicep flavor is public-endpoint-only by design. Defaults to false.')
param enablePrivateNetworking bool = false

@description('Optional. Enable monitoring (Application Insights + Log Analytics + diagnostics). Defaults to false.')
param enableMonitoring bool = false

@description('Optional. Enable redundancy (zone-redundancy, HA failover) for applicable resources. Defaults to false.')
param enableRedundancy bool = false

@description('Optional. Enable scalability (larger SKUs, autoscale) for applicable resources. Defaults to false.')
param enableScalability bool = false

// ============================================================================
// Derived Variables
// ============================================================================

var isAvm = deploymentFlavor == 'avm' || deploymentFlavor == 'avm-waf'
var isBicep = deploymentFlavor == 'bicep'

// Falls back to RG location when caller leaves `location` empty (azd default).
var effectiveLocation = !empty(location) ? location : resourceGroup().location

// ============================================================================
// Module: AVM Deployment (non-WAF and WAF)
// Activated when deploymentFlavor = 'avm' or 'avm-waf'
// WAF features (monitoring, private networking, scalability, redundancy)
// are activated via main.waf.parameters.json (which sets deploymentFlavor
// to 'avm-waf' and the corresponding enable* flags to true).
// ============================================================================

module avmDeployment './avm/main.bicep' = if (isAvm) {
  name: take('mod.flavor.avm.${solutionName}', 64)
  params: {
    solutionName: solutionName
    location: effectiveLocation
    solutionUniqueText: solutionUniqueText
    deploymentType: deploymentType
    gptModelName: gptModelName
    gptModelVersion: gptModelVersion
    gptDeploymentCapacity: gptDeploymentCapacity
    embeddingModelName: embeddingModelName
    embeddingModelVersion: embeddingModelVersion
    embeddingDeploymentCapacity: embeddingDeploymentCapacity
    existingLogAnalyticsWorkspaceId: existingLogAnalyticsWorkspaceId
    vmAdminUsername: vmAdminUsername
    vmAdminPassword: vmAdminPassword
    vmSize: vmSize
    tags: tags
    enableTelemetry: enableTelemetry
    enablePrivateNetworking: enablePrivateNetworking
    enableMonitoring: enableMonitoring
    enableRedundancy: enableRedundancy
    enableScalability: enableScalability
    azureAiServiceLocation: azureAiServiceLocation
  }
}

// ============================================================================
// Module: Vanilla Bicep Deployment
// Activated when deploymentFlavor = 'bicep'
// ============================================================================

module bicepDeployment './bicep/main.bicep' = if (isBicep) {
  name: take('mod.flavor.bicep.${solutionName}', 64)
  params: {
    solutionName: solutionName
    location: effectiveLocation
    solutionUniqueToken: solutionUniqueText
    deploymentType: deploymentType
    gptModelName: gptModelName
    gptModelVersion: gptModelVersion
    gptDeploymentCapacity: gptDeploymentCapacity
    embeddingModelName: embeddingModelName
    embeddingModelVersion: embeddingModelVersion
    embeddingDeploymentCapacity: embeddingDeploymentCapacity
    existingLogAnalyticsWorkspaceId: existingLogAnalyticsWorkspaceId
    tags: tags
    enableTelemetry: enableTelemetry
    enableMonitoring: enableMonitoring
    enableRedundancy: enableRedundancy
    enableScalability: enableScalability
    azureAiServiceLocation: azureAiServiceLocation
  }
}

// ============================================================================
// Outputs — Coalesced from whichever flavor was deployed
// ============================================================================

@description('Deployment flavor used.')
output DEPLOYMENT_FLAVOR string = deploymentFlavor

@description('Contains Azure Tenant ID.')
output AZURE_TENANT_ID string = subscription().tenantId

@description('Contains Solution Name.')
output SOLUTION_NAME string = isAvm ? avmDeployment!.outputs.SOLUTION_NAME : bicepDeployment!.outputs.SOLUTION_NAME

@description('Contains Resource Group Name.')
output RESOURCE_GROUP_NAME string = resourceGroup().name

@description('Contains Resource Group Location.')
output RESOURCE_GROUP_LOCATION string = isAvm ? avmDeployment!.outputs.RESOURCE_GROUP_LOCATION : bicepDeployment!.outputs.RESOURCE_GROUP_LOCATION

@description('Contains Resource Group ID.')
output AZURE_RESOURCE_GROUP_ID string = resourceGroup().id

@description('Contains Azure App Configuration Name.')
output AZURE_APP_CONFIG_NAME string = isAvm ? avmDeployment!.outputs.AZURE_APP_CONFIG_NAME : bicepDeployment!.outputs.AZURE_APP_CONFIG_NAME

@description('Contains Azure App Configuration Endpoint.')
output AZURE_APP_CONFIG_ENDPOINT string = isAvm ? avmDeployment!.outputs.AZURE_APP_CONFIG_ENDPOINT : bicepDeployment!.outputs.AZURE_APP_CONFIG_ENDPOINT

@description('Contains Storage Account Name.')
output STORAGE_ACCOUNT_NAME string = isAvm ? avmDeployment!.outputs.STORAGE_ACCOUNT_NAME : bicepDeployment!.outputs.STORAGE_ACCOUNT_NAME

@description('Contains Cosmos DB Name.')
output AZURE_COSMOSDB_NAME string = isAvm ? avmDeployment!.outputs.AZURE_COSMOSDB_NAME : bicepDeployment!.outputs.AZURE_COSMOSDB_NAME

@description('Contains Cognitive Service (Document Intelligence) Name.')
output AZURE_COGNITIVE_SERVICE_NAME string = isAvm ? avmDeployment!.outputs.AZURE_COGNITIVE_SERVICE_NAME : bicepDeployment!.outputs.AZURE_COGNITIVE_SERVICE_NAME

@description('Contains Azure Cognitive Service (Document Intelligence) Endpoint.')
output AZURE_COGNITIVE_SERVICE_ENDPOINT string = isAvm ? avmDeployment!.outputs.AZURE_COGNITIVE_SERVICE_ENDPOINT : bicepDeployment!.outputs.AZURE_COGNITIVE_SERVICE_ENDPOINT

@description('Contains Azure Search Service Name.')
output AZURE_SEARCH_SERVICE_NAME string = isAvm ? avmDeployment!.outputs.AZURE_SEARCH_SERVICE_NAME : bicepDeployment!.outputs.AZURE_SEARCH_SERVICE_NAME

@description('Contains Azure AKS Name.')
output AZURE_AKS_NAME string = isAvm ? avmDeployment!.outputs.AZURE_AKS_NAME : bicepDeployment!.outputs.AZURE_AKS_NAME

@description('Contains Azure AKS Managed Identity Principal ID.')
output AZURE_AKS_MI_ID string = isAvm ? avmDeployment!.outputs.AZURE_AKS_MI_ID : bicepDeployment!.outputs.AZURE_AKS_MI_ID

@description('Contains Azure Container Registry Name.')
output AZURE_CONTAINER_REGISTRY_NAME string = isAvm ? avmDeployment!.outputs.AZURE_CONTAINER_REGISTRY_NAME : bicepDeployment!.outputs.AZURE_CONTAINER_REGISTRY_NAME

@description('Contains Azure OpenAI Service Name.')
output AZURE_OPENAI_SERVICE_NAME string = isAvm ? avmDeployment!.outputs.AZURE_OPENAI_SERVICE_NAME : bicepDeployment!.outputs.AZURE_OPENAI_SERVICE_NAME

@description('Contains Azure OpenAI Service Endpoint.')
output AZURE_OPENAI_SERVICE_ENDPOINT string = isAvm ? avmDeployment!.outputs.AZURE_OPENAI_SERVICE_ENDPOINT : bicepDeployment!.outputs.AZURE_OPENAI_SERVICE_ENDPOINT

@description('Contains Azure Search Service Endpoint.')
output AZ_SEARCH_SERVICE_ENDPOINT string = isAvm ? avmDeployment!.outputs.AZ_SEARCH_SERVICE_ENDPOINT : bicepDeployment!.outputs.AZ_SEARCH_SERVICE_ENDPOINT

@description('Contains Azure GPT Model Deployment Name.')
output AZ_GPT4O_MODEL_ID string = isAvm ? avmDeployment!.outputs.AZ_GPT4O_MODEL_ID : bicepDeployment!.outputs.AZ_GPT4O_MODEL_ID

@description('Contains Azure GPT Model Name.')
output AZ_GPT4O_MODEL_NAME string = isAvm ? avmDeployment!.outputs.AZ_GPT4O_MODEL_NAME : bicepDeployment!.outputs.AZ_GPT4O_MODEL_NAME

@description('Contains Azure OpenAI Embedding Model Name.')
output AZ_GPT_EMBEDDING_MODEL_NAME string = isAvm ? avmDeployment!.outputs.AZ_GPT_EMBEDDING_MODEL_NAME : bicepDeployment!.outputs.AZ_GPT_EMBEDDING_MODEL_NAME

@description('Contains Azure OpenAI Embedding Model Deployment Name.')
output AZ_GPT_EMBEDDING_MODEL_ID string = isAvm ? avmDeployment!.outputs.AZ_GPT_EMBEDDING_MODEL_ID : bicepDeployment!.outputs.AZ_GPT_EMBEDDING_MODEL_ID

@description('Contains Application Insights Connection String.')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = isAvm ? avmDeployment!.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING : bicepDeployment!.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING

@description('Contains Application Insights Instrumentation Key.')
output APPLICATIONINSIGHTS_INSTRUMENTATION_KEY string = isAvm ? avmDeployment!.outputs.APPLICATIONINSIGHTS_INSTRUMENTATION_KEY : bicepDeployment!.outputs.APPLICATIONINSIGHTS_INSTRUMENTATION_KEY

@description('Contains Application Insights Name.')
output APPLICATIONINSIGHTS_NAME string = isAvm ? avmDeployment!.outputs.APPLICATIONINSIGHTS_NAME : bicepDeployment!.outputs.APPLICATIONINSIGHTS_NAME
