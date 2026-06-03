// ========== infra/avm/main.bicep ========== //
// Orchestrator for the AVM flavor of the DKM solution. Mirrors the behavior
// (and outputs) of `infra/bicep/main.bicep` (raw flavor) and the legacy
// `infra/main.bicep`, but every resource is provisioned through an
// Azure Verified Module (br/public:avm/res/...) wrapper under `./modules/`.
//
// Flavor pair documented in `infra/build_bicep.md`.

targetScope = 'resourceGroup'

// ============================================================================ //
// Parameters
// ============================================================================ //

@minLength(3)
@maxLength(20)
@description('Required. A unique prefix for all resources in this deployment (3-20 chars).')
param solutionName string = 'kmgs'

@description('Optional. Azure location for the solution. Defaults to the resource group location.')
param location string = ''

@maxLength(5)
@description('Optional. A unique token for the solution. Used to ensure resource names are unique.')
param solutionUniqueToken string = substring(uniqueString(subscription().id, resourceGroup().name, solutionName), 0, 5)

@minLength(1)
@description('Optional. GPT model deployment type.')
@allowed(['Standard', 'GlobalStandard'])
param deploymentType string = 'GlobalStandard'

@minLength(1)
@description('Optional. Name of the GPT model to deploy.')
@allowed(['gpt-4.1-mini'])
param gptModelName string = 'gpt-4.1-mini'

@description('Optional. Version of the GPT model to deploy.')
param gptModelVersion string = '2025-04-14'

@description('Optional. Capacity of the GPT model deployment.')
@minValue(10)
param gptDeploymentCapacity int = 100

@minLength(1)
@description('Optional. Name of the Text Embedding model to deploy.')
@allowed(['text-embedding-3-large'])
param embeddingModelName string = 'text-embedding-3-large'

@description('Optional. Version of the Text Embedding model to deploy.')
param embeddingModelVersion string = '1'

@description('Optional. Capacity of the Text Embedding model deployment.')
@minValue(10)
param embeddingDeploymentCapacity int = 100

@description('Optional. Existing Log Analytics Workspace Resource ID.')
param existingLogAnalyticsWorkspaceId string = ''

@description('Optional. Admin username for the Jumpbox VM (when enablePrivateNetworking is true).')
@secure()
param vmAdminUsername string?

@description('Optional. Admin password for the Jumpbox VM (when enablePrivateNetworking is true).')
@secure()
param vmAdminPassword string?

@description('Optional. Size of the Jumpbox VM (when enablePrivateNetworking is true).')
param vmSize string = 'Standard_D2s_v5'

@description('Optional. Tags to apply to all deployed Azure resources.')
param tags object = {}

@description('Optional. Enable private networking for applicable resources (WAF). Defaults to false.')
param enablePrivateNetworking bool = false

@description('Optional. Enable monitoring (LAW + App Insights + diagnostics). Defaults to false.')
param enableMonitoring bool = false

@description('Optional. Enable redundancy (zone-redundancy, HA failover). Defaults to false.')
param enableRedundancy bool = false

@description('Optional. Enable scalability (larger search SKU, etc.). Defaults to false.')
param enableScalability bool = false

@description('Optional. Enable/Disable usage telemetry for AVM modules. Defaults to true.')
param enableTelemetry bool = true

@metadata({
  azd: {
    type: 'location'
    usageName: [
      'OpenAI.GlobalStandard.gpt4.1-mini,150'
      'OpenAI.GlobalStandard.text-embedding-3-large,100'
    ]
  }
})
@description('Required. Azure region for AI Foundry / OpenAI deployment.')
param azureAiServiceLocation string

@description('Optional. User identifier embedded in resource group tags.')
param createdBy string = contains(deployer(), 'userPrincipalName') ? split(deployer().userPrincipalName, '@')[0] : deployer().objectId

// ============================================================================ //
// Variables
// ============================================================================ //

var solutionSuffix = toLower(trim(replace(
  replace(
    replace(replace(replace(replace('${solutionName}${solutionUniqueToken}', '-', ''), '_', ''), '.', ''), '/', ''),
    ' ',
    ''
  ),
  '*',
  ''
)))

var solutionLocation = empty(location) ? resourceGroup().location : location

// HA region pair for Cosmos DB (when enableRedundancy is true).
var cosmosDbZoneRedundantHaRegionPairs = {
  australiaeast: 'uksouth'
  centralus: 'eastus2'
  eastasia: 'southeastasia'
  eastus: 'centralus'
  eastus2: 'centralus'
  japaneast: 'australiaeast'
  northeurope: 'westeurope'
  southeastasia: 'eastasia'
  uksouth: 'westeurope'
  westeurope: 'northeurope'
}
var cosmosDbHaLocation = cosmosDbZoneRedundantHaRegionPairs[resourceGroup().location]

var useExistingLogAnalytics = !empty(existingLogAnalyticsWorkspaceId)
var existingLawSubscriptionId = useExistingLogAnalytics ? split(existingLogAnalyticsWorkspaceId, '/')[2] : subscription().subscriptionId
var existingLawResourceGroupName = useExistingLogAnalytics ? split(existingLogAnalyticsWorkspaceId, '/')[4] : resourceGroup().name
var existingLawName = useExistingLogAnalytics ? split(existingLogAnalyticsWorkspaceId, '/')[8] : ''

var gptModelDeployment = {
  modelName: gptModelName
  deploymentName: gptModelName
  deploymentVersion: gptModelVersion
  deploymentCapacity: gptDeploymentCapacity
}

var embeddingModelDeployment = {
  modelName: embeddingModelName
  deploymentName: embeddingModelName
  deploymentVersion: embeddingModelVersion
  deploymentCapacity: embeddingDeploymentCapacity
}

var openAiDeployments = [
  {
    name: gptModelDeployment.deploymentName
    model: {
      format: 'OpenAI'
      name: gptModelDeployment.modelName
      version: gptModelDeployment.deploymentVersion
    }
    sku: {
      name: deploymentType
      capacity: gptModelDeployment.deploymentCapacity
    }
  }
  {
    name: embeddingModelDeployment.deploymentName
    model: {
      format: 'OpenAI'
      name: embeddingModelDeployment.modelName
      version: embeddingModelDeployment.deploymentVersion
    }
    sku: {
      name: deploymentType
      capacity: embeddingModelDeployment.deploymentCapacity
    }
  }
]

// Private DNS Zones (indices kept in sync with `dnsZoneIndex` below).
var privateDnsZoneNames = [
  'privatelink.mongo.cosmos.azure.com'
  'privatelink.search.windows.net'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.queue.${environment().suffixes.storage}'
  'privatelink.api.azureml.ms'
  'privatelink.azconfig.io'
]
var dnsZoneIndex = {
  cosmosDB: 0
  search: 1
  cognitiveServices: 2
  openAI: 3
  storageBlob: 4
  storageQueue: 5
  aiFoundry: 6
  appConfig: 7
}

// Resource names.
var virtualNetworkName = 'vnet-${solutionSuffix}'
var openAiAccountName = 'oai-${solutionSuffix}'
var docIntelAccountName = 'di-${solutionSuffix}'
var aiSearchName = 'srch-${solutionSuffix}'
var cosmosDbAccountName = 'cosmos-${solutionSuffix}'
#disable-next-line BCP334
var storageAccountName = 'st${solutionSuffix}'
var appConfigName = 'appcs-${solutionSuffix}'
#disable-next-line BCP334
var containerRegistryName = 'cr${replace(solutionSuffix, '-', '')}'
var jumpboxVmName = take('vm-jumpbox-${solutionSuffix}', 15)
var aksClusterName = 'aks-${solutionSuffix}'

// Bool→string helper for AVM publicNetworkAccess.
var pnaString = enablePrivateNetworking ? 'Disabled' : 'Enabled'

// ============================================================================ //
// Resource Group Tags
// ============================================================================ //

resource resourceGroupTags 'Microsoft.Resources/tags@2023-07-01' = {
  name: 'default'
  properties: {
    tags: {
      ...resourceGroup().tags
      ...tags
      TemplateName: 'DKM'
      Type: enablePrivateNetworking ? 'WAF' : 'Non-WAF'
      CreatedBy: createdBy
      DeploymentName: deployment().name
    }
  }
}

// ============================================================================ //
// Identity
// ============================================================================ //

module userAssignedIdentity './modules/identity/user-assigned-identity.bicep' = {
  name: take('mod.identity.id-${solutionSuffix}', 64)
  params: {
    enableTelemetry: enableTelemetry
    solutionSuffix: solutionSuffix
    location: solutionLocation
    tags: tags
  }
}

// ============================================================================ //
// Monitoring
// ============================================================================ //

// Existing-workspace lookup (cross-subscription/RG-safe) when the user provides
// an explicit existing LAW resource ID.
resource existingLogAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = if (useExistingLogAnalytics) {
  name: existingLawName
  scope: resourceGroup(existingLawSubscriptionId, existingLawResourceGroupName)
}

// Otherwise, deploy a fresh AVM-backed LAW.
module logAnalyticsWorkspace './modules/monitoring/log-analytics.bicep' = if (enableMonitoring && !useExistingLogAnalytics) {
  name: take('mod.monitoring.law.log-${solutionSuffix}', 64)
  params: {
    enableTelemetry: enableTelemetry
    solutionSuffix: solutionSuffix
    location: solutionLocation
    tags: tags
    publicNetworkAccessForIngestion: enablePrivateNetworking ? 'Disabled' : 'Enabled'
    publicNetworkAccessForQuery: enablePrivateNetworking ? 'Disabled' : 'Enabled'
  }
}

var logAnalyticsWorkspaceResourceId = useExistingLogAnalytics
  ? existingLogAnalytics.id
  : (enableMonitoring ? logAnalyticsWorkspace!.outputs.resourceId : '')

module applicationInsights './modules/monitoring/app-insights.bicep' = if (enableMonitoring) {
  name: take('mod.monitoring.appi-${solutionSuffix}', 64)
  params: {
    enableTelemetry: enableTelemetry
    solutionSuffix: solutionSuffix
    location: solutionLocation
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceResourceId
  }
}

// ============================================================================ //
// Networking (only when enablePrivateNetworking is true)
// ============================================================================ //

module virtualNetwork './modules/networking/virtual-network.bicep' = if (enablePrivateNetworking) {
  name: take('mod.networking.vnet.${virtualNetworkName}', 64)
  params: {
    enableTelemetry: enableTelemetry
    name: virtualNetworkName
    location: solutionLocation
    tags: tags
    addressPrefixes: ['10.0.0.0/20']
    resourceSuffix: solutionSuffix
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalyticsWorkspaceResourceId : ''
  }
}

module privateDnsZones './modules/networking/private-dns-zone.bicep' = [
  for (zoneName, i) in privateDnsZoneNames: if (enablePrivateNetworking) {
    name: take('mod.networking.pdz.${i}-${solutionSuffix}', 64)
    params: {
      enableTelemetry: enableTelemetry
      name: zoneName
      virtualNetworkResourceId: virtualNetwork!.outputs.resourceId
      tags: tags
    }
  }
]

module bastionHost './modules/networking/bastion-host.bicep' = if (enablePrivateNetworking) {
  name: take('mod.networking.bas.${solutionSuffix}', 64)
  params: {
    enableTelemetry: enableTelemetry
    solutionSuffix: solutionSuffix
    location: solutionLocation
    tags: tags
    virtualNetworkResourceId: virtualNetwork!.outputs.resourceId
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalyticsWorkspaceResourceId : ''
  }
}

module jumpboxVm './modules/compute/virtual-machine.bicep' = if (enablePrivateNetworking) {
  name: take('mod.compute.vm.${jumpboxVmName}', 64)
  params: {
    enableTelemetry: enableTelemetry
    name: jumpboxVmName
    location: solutionLocation
    tags: tags
    vmSize: vmSize
    adminUsername: vmAdminUsername ?? 'JumpboxAdminUser'
    adminPassword: vmAdminPassword ?? 'JumpboxAdminP@ssw0rd1234!'
    subnetResourceId: virtualNetwork!.outputs.jumpboxSubnetResourceId
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalyticsWorkspaceResourceId : ''
  }
}

// ============================================================================ //
// Data (Storage + Cosmos)
// ============================================================================ //

module storageAccount './modules/data/storage-account.bicep' = {
  name: take('mod.data.st.${storageAccountName}', 64)
  params: {
    enableTelemetry: enableTelemetry
    #disable-next-line BCP334
    name: storageAccountName
    location: solutionLocation
    tags: tags
    publicNetworkAccessDisabled: enablePrivateNetworking
    storageBlobDataContributorPrincipalId: userAssignedIdentity.outputs.principalId
    privateEndpointSubnetResourceId: enablePrivateNetworking ? virtualNetwork!.outputs.pepsSubnetResourceId : ''
    blobPrivateDnsZoneResourceId: enablePrivateNetworking ? privateDnsZones[dnsZoneIndex.storageBlob]!.outputs.resourceId : ''
    queuePrivateDnsZoneResourceId: enablePrivateNetworking ? privateDnsZones[dnsZoneIndex.storageQueue]!.outputs.resourceId : ''
  }
}

module cosmosDb './modules/data/cosmos-db.bicep' = {
  name: take('mod.data.cosmos.${cosmosDbAccountName}', 64)
  params: {
    enableTelemetry: enableTelemetry
    name: cosmosDbAccountName
    location: solutionLocation
    tags: tags
    enableRedundancy: enableRedundancy
    haLocation: enableRedundancy ? cosmosDbHaLocation : ''
    publicNetworkAccess: pnaString
    createPrivateEndpoint: enablePrivateNetworking
    privateEndpointSubnetResourceId: enablePrivateNetworking ? virtualNetwork!.outputs.pepsSubnetResourceId : ''
    mongoPrivateDnsZoneResourceId: enablePrivateNetworking ? privateDnsZones[dnsZoneIndex.cosmosDB]!.outputs.resourceId : ''
  }
}

// ============================================================================ //
// AI (OpenAI + Document Intelligence + AI Search)
// ============================================================================ //

module openAi './modules/ai/openai.bicep' = {
  name: take('mod.ai.openai.${openAiAccountName}', 64)
  params: {
    enableTelemetry: enableTelemetry
    name: openAiAccountName
    location: azureAiServiceLocation
    tags: tags
    publicNetworkAccess: pnaString
    principalId: userAssignedIdentity.outputs.principalId
    deployments: openAiDeployments
    createPrivateEndpoint: enablePrivateNetworking
    privateEndpointSubnetResourceId: enablePrivateNetworking ? virtualNetwork!.outputs.pepsSubnetResourceId : ''
    cognitiveServicesPrivateDnsZoneResourceId: enablePrivateNetworking ? privateDnsZones[dnsZoneIndex.cognitiveServices]!.outputs.resourceId : ''
    openAiPrivateDnsZoneResourceId: enablePrivateNetworking ? privateDnsZones[dnsZoneIndex.openAI]!.outputs.resourceId : ''
  }
}

module documentIntelligence './modules/ai/document-intelligence.bicep' = {
  name: take('mod.ai.di.${docIntelAccountName}', 64)
  params: {
    enableTelemetry: enableTelemetry
    name: docIntelAccountName
    location: solutionLocation
    tags: tags
    publicNetworkAccess: pnaString
    principalId: userAssignedIdentity.outputs.principalId
    createPrivateEndpoint: enablePrivateNetworking
    privateEndpointSubnetResourceId: enablePrivateNetworking ? virtualNetwork!.outputs.pepsSubnetResourceId : ''
    cognitiveServicesPrivateDnsZoneResourceId: enablePrivateNetworking ? privateDnsZones[dnsZoneIndex.cognitiveServices]!.outputs.resourceId : ''
  }
}

module aiSearch './modules/ai/ai-search.bicep' = {
  name: take('mod.ai.srch.${aiSearchName}', 64)
  params: {
    enableTelemetry: enableTelemetry
    name: aiSearchName
    location: solutionLocation
    tags: tags
    skuName: enableScalability ? 'standard' : 'basic'
    publicNetworkAccess: pnaString
    userAssignedIdentityResourceId: userAssignedIdentity.outputs.resourceId
    principalId: userAssignedIdentity.outputs.principalId
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalyticsWorkspaceResourceId : ''
    createPrivateEndpoint: enablePrivateNetworking
    privateEndpointSubnetResourceId: enablePrivateNetworking ? virtualNetwork!.outputs.pepsSubnetResourceId : ''
    searchPrivateDnsZoneResourceId: enablePrivateNetworking ? privateDnsZones[dnsZoneIndex.search]!.outputs.resourceId : ''
  }
}

// ============================================================================ //
// Compute (AKS + ACR)
// ============================================================================ //

module aks './modules/compute/aks.bicep' = {
  name: take('mod.compute.aks.${aksClusterName}', 64)
  params: {
    enableTelemetry: enableTelemetry
    name: aksClusterName
    location: solutionLocation
    tags: tags
    agentPoolSubnetResourceId: enablePrivateNetworking ? virtualNetwork!.outputs.webSubnetResourceId : ''
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalyticsWorkspaceResourceId : ''
    enableDefender: enablePrivateNetworking && enableMonitoring
    contributorPrincipalId: userAssignedIdentity.outputs.principalId
  }
}

module containerRegistry './modules/compute/container-registry.bicep' = {
  name: take('mod.compute.acr.${containerRegistryName}', 64)
  params: {
    enableTelemetry: enableTelemetry
    #disable-next-line BCP334
    name: containerRegistryName
    location: solutionLocation
    tags: tags
    acrSku: 'Standard'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
    acrPullPrincipalId: aks.outputs.kubeletIdentityPrincipalId
  }
}

// ============================================================================ //
// App Configuration (must come last — depends on most other outputs)
// ============================================================================ //

var keyValues = [
  {
    name: 'ApplicationInsights:ConnectionString'
    value: enableMonitoring ? applicationInsights!.outputs.connectionString : ''
  }
  { name: 'Application:AIServices:GPT-4o-mini:Endpoint', value: openAi.outputs.endpoint }
  { name: 'Application:AIServices:GPT-4o-mini:ModelName', value: gptModelDeployment.modelName }
  { name: 'Application:Services:KernelMemory:Endpoint', value: 'http://kernelmemory-service' }
  { name: 'Application:Services:PersistentStorage:CosmosMongo:Collections:ChatHistory:Collection', value: 'ChatHistory' }
  { name: 'Application:Services:PersistentStorage:CosmosMongo:Collections:ChatHistory:Database', value: 'DPS' }
  { name: 'Application:Services:PersistentStorage:CosmosMongo:Collections:DocumentManager:Collection', value: 'Documents' }
  { name: 'Application:Services:PersistentStorage:CosmosMongo:Collections:DocumentManager:Database', value: 'DPS' }
  { name: 'Application:Services:PersistentStorage:CosmosMongo:ConnectionString', value: cosmosDb.outputs.primaryConnectionString }
  { name: 'Application:Services:AzureAISearch:Endpoint', value: aiSearch.outputs.endpoint }
  { name: 'KernelMemory:Services:AzureAIDocIntel:Auth', value: 'AzureIdentity' }
  { name: 'KernelMemory:Services:AzureAIDocIntel:Endpoint', value: documentIntelligence.outputs.endpoint }
  { name: 'KernelMemory:Services:AzureAISearch:Auth', value: 'AzureIdentity' }
  { name: 'KernelMemory:Services:AzureAISearch:Endpoint', value: aiSearch.outputs.endpoint }
  { name: 'KernelMemory:Services:AzureBlobs:Account', value: storageAccount.outputs.name }
  { name: 'KernelMemory:Services:AzureBlobs:Auth', value: 'AzureIdentity' }
  { name: 'KernelMemory:Services:AzureBlobs:Container', value: 'smemory' }
  { name: 'KernelMemory:Services:AzureOpenAIEmbedding:Auth', value: 'AzureIdentity' }
  { name: 'KernelMemory:Services:AzureOpenAIEmbedding:Deployment', value: embeddingModelDeployment.deploymentName }
  { name: 'KernelMemory:Services:AzureOpenAIEmbedding:Endpoint', value: openAi.outputs.endpoint }
  { name: 'KernelMemory:Services:AzureOpenAIText:Auth', value: 'AzureIdentity' }
  { name: 'KernelMemory:Services:AzureOpenAIText:Deployment', value: gptModelDeployment.deploymentName }
  { name: 'KernelMemory:Services:AzureOpenAIText:Endpoint', value: openAi.outputs.endpoint }
  { name: 'KernelMemory:Services:AzureQueues:Account', value: storageAccount.outputs.name }
  { name: 'KernelMemory:Services:AzureQueues:Auth', value: 'AzureIdentity' }
]

module appConfiguration './modules/data/app-configuration.bicep' = {
  name: take('mod.data.appcs.${appConfigName}', 64)
  params: {
    enableTelemetry: enableTelemetry
    name: appConfigName
    location: solutionLocation
    tags: tags
    disableLocalAuth: enablePrivateNetworking
    publicNetworkAccess: pnaString
    appConfigDataReaderPrincipalId: userAssignedIdentity.outputs.principalId
    createPrivateEndpoint: enablePrivateNetworking
    privateEndpointSubnetResourceId: enablePrivateNetworking ? virtualNetwork!.outputs.pepsSubnetResourceId : ''
    privateDnsZoneResourceId: enablePrivateNetworking ? privateDnsZones[dnsZoneIndex.appConfig]!.outputs.resourceId : ''
    keyValues: keyValues
  }
}

// ============================================================================ //
// Outputs (kept name-compatible with infra/main.bicep so azd env vars match)
// ============================================================================ //

@description('Contains Azure Tenant ID.')
output AZURE_TENANT_ID string = subscription().tenantId

@description('Contains Solution Name.')
output SOLUTION_NAME string = solutionSuffix

@description('Contains Resource Group Name.')
output RESOURCE_GROUP_NAME string = resourceGroup().name

@description('Contains Resource Group Location.')
output RESOURCE_GROUP_LOCATION string = solutionLocation

@description('Contains Resource Group ID.')
output AZURE_RESOURCE_GROUP_ID string = resourceGroup().id

@description('Contains Azure App Configuration Name.')
output AZURE_APP_CONFIG_NAME string = appConfiguration.outputs.name

@description('Contains Azure App Configuration Endpoint.')
output AZURE_APP_CONFIG_ENDPOINT string = appConfiguration.outputs.endpoint

@description('Contains Storage Account Name.')
output STORAGE_ACCOUNT_NAME string = storageAccount.outputs.name

@description('Contains Cosmos DB Name.')
output AZURE_COSMOSDB_NAME string = cosmosDb.outputs.name

@description('Contains Cognitive Service (Document Intelligence) Name.')
output AZURE_COGNITIVE_SERVICE_NAME string = documentIntelligence.outputs.name

@description('Contains Azure Cognitive Service (Document Intelligence) Endpoint.')
output AZURE_COGNITIVE_SERVICE_ENDPOINT string = documentIntelligence.outputs.endpoint

@description('Contains Azure Search Service Name.')
output AZURE_SEARCH_SERVICE_NAME string = aiSearch.outputs.name

@description('Contains Azure AKS Name.')
output AZURE_AKS_NAME string = aks.outputs.name

@description('Contains Azure AKS Managed Identity Principal ID.')
output AZURE_AKS_MI_ID string = aks.outputs.systemAssignedIdentityPrincipalId

@description('Contains Azure Container Registry Name.')
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name

@description('Contains Azure OpenAI Service Name.')
output AZURE_OPENAI_SERVICE_NAME string = openAi.outputs.name

@description('Contains Azure OpenAI Service Endpoint.')
output AZURE_OPENAI_SERVICE_ENDPOINT string = openAi.outputs.endpoint

@description('Contains Azure Search Service Endpoint.')
output AZ_SEARCH_SERVICE_ENDPOINT string = aiSearch.outputs.endpoint

@description('Contains Azure GPT Model Deployment Name.')
output AZ_GPT4O_MODEL_ID string = gptModelDeployment.deploymentName

@description('Contains Azure GPT Model Name.')
output AZ_GPT4O_MODEL_NAME string = gptModelDeployment.modelName

@description('Contains Azure OpenAI Embedding Model Name.')
output AZ_GPT_EMBEDDING_MODEL_NAME string = embeddingModelDeployment.modelName

@description('Contains Azure OpenAI Embedding Model Deployment Name.')
output AZ_GPT_EMBEDDING_MODEL_ID string = embeddingModelDeployment.deploymentName

@description('Contains Application Insights Connection String.')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = enableMonitoring ? applicationInsights!.outputs.connectionString : ''

@description('Contains Application Insights Instrumentation Key.')
output APPLICATIONINSIGHTS_INSTRUMENTATION_KEY string = enableMonitoring ? applicationInsights!.outputs.instrumentationKey : ''

@description('Contains Application Insights Name.')
output APPLICATIONINSIGHTS_NAME string = enableMonitoring ? applicationInsights!.outputs.name : ''
