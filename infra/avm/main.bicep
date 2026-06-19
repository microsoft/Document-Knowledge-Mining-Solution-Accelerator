// ============================================================================
// main.bicep — Orchestrator (AVM flavor)
// Description: Pure orchestrator for the DKM (Document Knowledge Mining)
//              solution. Mirrors the pattern of
//              microsoft/agentic-applications-for-unified-data-foundation-solution-accelerator
//              `psl/infra-restructure-new` branch, adapted for the DKM
//              resource set (AKS + ACR + OpenAI + Document Intelligence +
//              AI Search + Cosmos Mongo + Storage + App Configuration).
//              All resource names are derived from params — no hardcoded names.
//              This file only calls modules; no inline resource definitions
//              except resource-group tags and a small set of inline RBAC
//              assignments wired to the User-Assigned Managed Identity that
//              backs the AKS workload.
//              Supports WAF-aligned deployment via feature flags.
// ============================================================================
targetScope = 'resourceGroup'

// ============================================================================
// Parameters — Core
// ============================================================================

@minLength(3)
@maxLength(20)
@description('Optional. A unique application/solution name used as base for all resource naming.')
param solutionName string = 'kmgs'

@maxLength(5)
@description('Optional. A unique text suffix appended to resource names for uniqueness.')
param solutionUniqueText string = substring(uniqueString(subscription().id, resourceGroup().name, solutionName), 0, 5)

@description('Optional. Primary Azure region for resource deployment.')
param location string = resourceGroup().location

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. Enable/Disable usage telemetry for AVM modules.')
param enableTelemetry bool = true

// ============================================================================
// Parameters — WAF Feature Flags
// ============================================================================

@description('Optional. Enable monitoring for applicable resources, aligned with the Well Architected Framework recommendations. Defaults to false.')
param enableMonitoring bool = false

@description('Optional. Enable private networking for applicable resources, aligned with the Well Architected Framework recommendations. Defaults to false.')
param enablePrivateNetworking bool = false

@description('Optional. Enable scalability for applicable resources, aligned with the Well Architected Framework recommendations. Defaults to false.')
param enableScalability bool = false

@description('Optional. Enable redundancy for applicable resources, aligned with the Well Architected Framework recommendations. Defaults to false.')
param enableRedundancy bool = false

// ============================================================================
// Parameters — VM (applicable when enablePrivateNetworking = true)
// ============================================================================

@secure()
@description('Optional. The user name for the administrator account of the jumpbox virtual machine. Required by Azure at provisioning time but not used for login when Entra ID is enabled.')
param vmAdminUsername string?

@secure()
@description('Optional. The password for the administrator account of the jumpbox virtual machine. Auto-generated if not provided. Not used for login when Entra ID is enabled.')
param vmAdminPassword string?

@description('Optional. The size of the jumpbox virtual machine. Defaults to Standard_D2s_v5.')
param vmSize string = 'Standard_D2s_v5'

// ============================================================================
// Parameters — AI Configuration
// ============================================================================

@metadata({
  azd: {
    type: 'location'
    usageName: [
      'OpenAI.GlobalStandard.gpt4.1-mini,150'
      'OpenAI.GlobalStandard.text-embedding-3-large,100'
    ]
  }
})
@description('Required. Location for AI Services and model deployments.')
param azureAiServiceLocation string

@allowed(['Standard', 'GlobalStandard'])
@description('Optional. GPT model deployment type.')
param deploymentType string = 'GlobalStandard'

@allowed(['gpt-4.1-mini'])
@description('Optional. Name of the GPT model to deploy.')
param gptModelName string = 'gpt-4.1-mini'

@description('Optional. Version of the GPT model to deploy.')
param gptModelVersion string = '2025-04-14'

@minValue(10)
@description('Optional. Capacity of the GPT deployment (TPM in thousands).')
param gptDeploymentCapacity int = 100

@allowed(['text-embedding-3-large'])
@description('Optional. Name of the Text Embedding model to deploy.')
param embeddingModelName string = 'text-embedding-3-large'

@description('Optional. Version of the Text Embedding model to deploy.')
param embeddingModelVersion string = '1'

@minValue(10)
@description('Optional. Capacity of the Text Embedding model deployment.')
param embeddingDeploymentCapacity int = 100

// ============================================================================
// Parameters — Existing Resources
// ============================================================================

@description('Optional. Resource ID of an existing Log Analytics workspace (empty = create new).')
param existingLogAnalyticsWorkspaceId string = ''

// ============================================================================
// Parameters — Identity
// ============================================================================

// ============================================================================
// Variables
// ============================================================================

var solutionSuffix = toLower(trim(replace(replace(replace(replace(replace(replace('${solutionName}${solutionUniqueText}', '-', ''), '_', ''), '.', ''), '/', ''), ' ', ''), '*', '')))

// Literal resource names — required so 'existing' resource refs further
// down can be resolved at compile time (BCP307 prevents reading properties
// on existing resources whose name depends on a module output).
var aksName = 'aks-${solutionSuffix}'
var cosmosName = 'cosmos-${solutionSuffix}'

// DKM SAI migration: compile-time resource-name vars previously used as GUID
// salts in the kubelet RBAC role assignments at the end of this file. Those
// RBAC blocks are now commented out (pods authenticate via VMSS SystemAssigned
// identity bootstrapped by Deployment/resourcedeployment.ps1, NOT via the
// kubelet UAI). Vars preserved for easy re-enable if the workload ever moves
// to Workload Identity or AZURE_CLIENT_ID injection.
// var openAiAccountName = 'oai-${solutionSuffix}'
// var docIntelAccountName = 'di-${solutionSuffix}'
// var aiSearchName = 'srch-${solutionSuffix}'
// var storageAccountName = take('st${solutionSuffix}', 24)
// var appConfigName = 'appcs-${solutionSuffix}'

var deployerInfo = deployer()
var deployingUserPrincipalId = deployerInfo.objectId
// Auto-detect the principal type: deployer() only returns a (non-empty) userPrincipalName
// for interactive user sign-ins; CI/OIDC service principals have none, so they resolve
// to 'ServicePrincipal'. This keeps role assignments valid in both local and pipeline runs.
var deployingUserPrincipalType = (contains(deployerInfo, 'userPrincipalName') && !empty(deployerInfo.userPrincipalName)) ? 'User' : 'ServicePrincipal'
var createdBy = contains(deployerInfo, 'userPrincipalName') ? split(deployerInfo.userPrincipalName, '@')[0] : deployerInfo.objectId

// Tags: merge caller-supplied tags with standard metadata.
var existingTags = resourceGroup().tags ?? {}
var resourceTags = union(existingTags, tags, {
  TemplateName: 'DKM'
  CreatedBy: createdBy
  DeploymentName: deployment().name
  Type: enablePrivateNetworking ? 'WAF' : 'Non-WAF'
})

// WAF: Region pairs for redundancy (Log Analytics replication).
var replicaRegionPairs = {
  australiaeast: 'australiasoutheast'
  centralus: 'eastus2'
  eastasia: 'southeastasia'
  eastus: 'centralus'
  eastus2: 'centralus'
  francecentral: 'westeurope'
  japaneast: 'eastasia'
  northeurope: 'westeurope'
  southeastasia: 'eastasia'
  swedencentral: 'northeurope'
  uksouth: 'westeurope'
  westeurope: 'northeurope'
  westus: 'centralus'
  westus3: 'centralus'
}
var replicaLocation = replicaRegionPairs[?location] ?? ''

// WAF: Region pairs for Cosmos DB zone-redundant HA.
var cosmosDbHaRegionPairs = {
  australiaeast: 'uksouth'
  centralus: 'eastus2'
  eastasia: 'southeastasia'
  eastus: 'centralus'
  eastus2: 'centralus'
  francecentral: 'westeurope'
  japaneast: 'australiaeast'
  northeurope: 'westeurope'
  southeastasia: 'eastasia'
  swedencentral: 'northeurope'
  uksouth: 'westeurope'
  westeurope: 'northeurope'
  westus: 'centralus'
  westus3: 'centralus'
}
var cosmosDbHaLocation = cosmosDbHaRegionPairs[?location] ?? ''

// WAF: Private DNS zones for private endpoints (DKM-specific set).
var privateDnsZones = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.search.windows.net'
  'privatelink.mongo.cosmos.azure.com'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.azconfig.io'
  '${toLower(location)}.privatelink.azurecr.io'
]
var dnsZoneIndex = {
  cognitiveServices: 0
  openAI: 1
  search: 2
  cosmosDb: 3
  blob: 4
  appConfig: 5
  containerRegistry: 6
}

// Model deployments configuration.
var aiModelDeployments = [
  {
    name: gptModelName
    model: gptModelName
    sku: { name: deploymentType, capacity: gptDeploymentCapacity }
    version: gptModelVersion
    raiPolicyName: 'Microsoft.Default'
  }
  {
    name: embeddingModelName
    model: embeddingModelName
    sku: { name: deploymentType, capacity: embeddingDeploymentCapacity }
    version: embeddingModelVersion
    raiPolicyName: 'Microsoft.Default'
  }
]

// Existing Log Analytics workspace lookup (cross-subscription/RG-safe).
var useExistingLogAnalytics = !empty(existingLogAnalyticsWorkspaceId)

// ============================================================================
// Resource Group Tags
// ============================================================================

resource resourceGroupTags 'Microsoft.Resources/tags@2024-11-01' = {
  name: 'default'
  properties: {
    tags: resourceTags
  }
}

// ============================================================================
// Module: Monitoring
// ============================================================================

resource existingLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = if (useExistingLogAnalytics) {
  name: split(existingLogAnalyticsWorkspaceId, '/')[8]
  scope: resourceGroup(split(existingLogAnalyticsWorkspaceId, '/')[2], split(existingLogAnalyticsWorkspaceId, '/')[4])
}

module log_analytics './modules/monitoring/log-analytics.bicep' = if (enableMonitoring && !useExistingLogAnalytics) {
  name: take('module.log-analytics.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    retentionInDays: 365
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    enableReplication: enableRedundancy && !empty(replicaLocation)
    replicationLocation: enableRedundancy ? replicaLocation : ''
    dailyQuotaGb: enableRedundancy ? '150' : ''
    dataSources: enablePrivateNetworking ? [
      {
        tags: tags
        eventLogName: 'Application'
        eventTypes: [{ eventType: 'Error' }, { eventType: 'Warning' }, { eventType: 'Information' }]
        kind: 'WindowsEvent'
        name: 'applicationEvent'
      }
      {
        counterName: '% Processor Time'
        instanceName: '*'
        intervalSeconds: 60
        kind: 'WindowsPerformanceCounter'
        name: 'windowsPerfCounter1'
        objectName: 'Processor'
      }
    ] : []
  }
}

// Resolve workspace resource ID and name — existing or new.
var logAnalyticsWorkspaceResourceId = useExistingLogAnalytics
  ? existingLogAnalyticsWorkspace.id
  : (enableMonitoring ? log_analytics!.outputs.resourceId : '')
var logAnalyticsWorkspaceName = useExistingLogAnalytics
  ? split(existingLogAnalyticsWorkspaceId, '/')[8]
  : (enableMonitoring ? log_analytics!.outputs.name : '')

// WAF: Diagnostic settings helper — reused across modules.
var monitoringDiagnosticSettings = enableMonitoring ? [{ workspaceResourceId: logAnalyticsWorkspaceResourceId }] : []

module app_insights './modules/monitoring/app-insights.bicep' = if (enableMonitoring) {
  name: take('module.app-insights.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    workspaceResourceId: logAnalyticsWorkspaceResourceId
    retentionInDays: 365
    disableIpMasking: false
  }
}

// ============================================================================
// Module: Networking (WAF — conditional on enablePrivateNetworking)
// ============================================================================

module virtualNetwork './modules/networking/virtual-network.bicep' = if (enablePrivateNetworking) {
  name: take('module.virtual-network.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    addressPrefixes: ['10.0.0.0/8']
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalyticsWorkspaceResourceId : ''
    resourceSuffix: solutionSuffix
  }
}

// Bastion Host — secure access to jumpbox VM.
module bastionHost './modules/networking/bastion-host.bicep' = if (enablePrivateNetworking) {
  name: take('module.bastion-host.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    virtualNetworkResourceId: virtualNetwork!.outputs.resourceId
    publicIPDiagnosticSettings: enableMonitoring ? [{ workspaceResourceId: logAnalyticsWorkspaceResourceId }] : null
    diagnosticSettings: enableMonitoring ? [{ workspaceResourceId: logAnalyticsWorkspaceResourceId }] : null
  }
}

// WAF: Maintenance Configuration for VM patching.
module maintenanceConfiguration './modules/compute/maintenance-configuration.bicep' = if (enablePrivateNetworking) {
  name: take('module.maintenance-configuration.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
  }
}

// WAF: Data Collection Rules for VM monitoring.
var dataCollectionRulesLocation = useExistingLogAnalytics
  ? existingLogAnalyticsWorkspace!.location
  : (enableMonitoring ? log_analytics!.outputs.location : location)
module windowsVmDataCollectionRules './modules/monitoring/data-collection-rule.bicep' = if (enablePrivateNetworking && enableMonitoring) {
  name: take('module.data-collection-rule.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: dataCollectionRulesLocation
    tags: tags
    enableTelemetry: enableTelemetry
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
}

// WAF: Proximity Placement Group for VM.
var virtualMachineAvailabilityZone = 1
module proximityPlacementGroup './modules/compute/proximity-placement-group.bicep' = if (enablePrivateNetworking) {
  name: take('module.proximity-placement-group.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    availabilityZone: virtualMachineAvailabilityZone
    vmSizes: [vmSize]
  }
}

// Jumpbox VM — administration access when private networking is enabled.
// Login is via Microsoft Entra ID through Azure Bastion (not local credentials).
module virtualMachine './modules/compute/virtual-machine.bicep' = if (enablePrivateNetworking) {
  name: take('module.virtual-machine.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    vmSize: vmSize
    availabilityZone: virtualMachineAvailabilityZone
    adminUsername: vmAdminUsername ?? 'JumpboxAdminUser'
    adminPassword: vmAdminPassword ?? 'Vm!${uniqueString(subscription().subscriptionId, solutionName)}${guid(subscription().subscriptionId, solutionName, 'vm-admin-password')}'
    subnetResourceId: virtualNetwork!.outputs.administrationSubnetResourceId
    deployingUserPrincipalId: deployingUserPrincipalId
    deployingUserPrincipalType: deployingUserPrincipalType
    roleAssignments: [
      {
        roleDefinitionIdOrName: '1c0163c0-47e6-4577-8991-ea5c82e286e4' // Virtual Machine Administrator Login
        principalId: deployingUserPrincipalId
        principalType: deployingUserPrincipalType
      }
    ]
    diagnosticSettings: enableMonitoring ? [{ workspaceResourceId: logAnalyticsWorkspaceResourceId }] : null
    maintenanceConfigurationResourceId: maintenanceConfiguration!.outputs.resourceId
    proximityPlacementGroupResourceId: proximityPlacementGroup!.outputs.resourceId
    extensionMonitoringAgentConfig: enableMonitoring ? {
      dataCollectionRuleAssociations: [
        {
          dataCollectionRuleResourceId: windowsVmDataCollectionRules!.outputs.resourceId
          name: 'send-${logAnalyticsWorkspaceName}'
        }
      ]
      enabled: true
      tags: tags
    } : null
  }
}

// Private DNS Zones — one per service, linked to VNet.
@batchSize(5)
module privateDnsZoneDeployments './modules/networking/private-dns-zone.bicep' = [
  for (zone, i) in privateDnsZones: if (enablePrivateNetworking) {
    name: take('module.private-dns-zone.${split(zone, '.')[1]}.${solutionName}', 64)
    params: {
      name: zone
      tags: tags
      enableTelemetry: enableTelemetry
      virtualNetworkLinks: [
        {
          name: take('vnetlink-${virtualNetwork!.outputs.name}-${split(zone, '.')[1]}', 80)
          virtualNetworkResourceId: virtualNetwork!.outputs.resourceId
        }
      ]
    }
  }
]

// ============================================================================
// Module: Identity (User-Assigned Managed Identity for AKS workload)
// ============================================================================
// DKM SAI migration: workload UAI removed. AKS kubelet system-assigned
// identity (auto-created by Microsoft.ContainerService/managedClusters) is
// now the runtime identity pods consume via DefaultAzureCredential → IMDS.
// All RBAC previously granted to this UAI is reassigned to the kubelet
// principalId via standalone role-assignment resources at the bottom of
// this file (search "DKM SAI migration: kubelet RBAC").
//
// module userAssignedIdentity './modules/identity/managed-identity.bicep' = {
//   name: take('module.managed-identity.${solutionName}', 64)
//   params: {
//     solutionName: solutionSuffix
//     location: location
//     tags: tags
//     enableTelemetry: enableTelemetry
//   }
// }

// ============================================================================
// Module: AI Services (OpenAI + Document Intelligence + model deployments)
// ============================================================================

module openAi './modules/ai/ai-services.bicep' = {
  name: take('module.openai.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    namePrefix: 'oai'
    kind: 'OpenAI'
    location: azureAiServiceLocation
    tags: tags
    enableTelemetry: enableTelemetry
    publicNetworkAccess: 'Enabled' // WAF: keep public for ARM writes + pod access; RBAC gates auth
    diagnosticSettings: monitoringDiagnosticSettings
    enablePrivateNetworking: enablePrivateNetworking
    privateEndpointSubnetId: enablePrivateNetworking ? virtualNetwork!.outputs.backendSubnetResourceId : ''
    privateDnsZoneResourceIds: enablePrivateNetworking ? [
      privateDnsZoneDeployments[dnsZoneIndex.openAI]!.outputs.resourceId
      privateDnsZoneDeployments[dnsZoneIndex.cognitiveServices]!.outputs.resourceId
    ] : []
    roleAssignments: [
      // DKM SAI migration: UAI grants removed. Kubelet RBAC defined at end of file.
      // {
      //   roleDefinitionIdOrName: 'a001fd3d-188f-4b5d-821b-7da978bf7442' // Cognitive Services OpenAI Contributor
      //   principalId: userAssignedIdentity.outputs.principalId
      //   principalType: 'ServicePrincipal'
      // }
      // {
      //   roleDefinitionIdOrName: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User
      //   principalId: userAssignedIdentity.outputs.principalId
      //   principalType: 'ServicePrincipal'
      // }
    ]
  }
}

module documentIntelligence './modules/ai/ai-services.bicep' = {
  name: take('module.document-intelligence.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    namePrefix: 'di'
    kind: 'FormRecognizer'
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    publicNetworkAccess: 'Enabled' // WAF: keep public for ARM writes + pod access; RBAC gates auth
    diagnosticSettings: monitoringDiagnosticSettings
    enablePrivateNetworking: enablePrivateNetworking
    privateEndpointSubnetId: enablePrivateNetworking ? virtualNetwork!.outputs.backendSubnetResourceId : ''
    privateDnsZoneResourceIds: enablePrivateNetworking ? [
      privateDnsZoneDeployments[dnsZoneIndex.cognitiveServices]!.outputs.resourceId
    ] : []
    roleAssignments: [
      // DKM SAI migration: UAI grant removed. Kubelet RBAC defined at end of file.
      // {
      //   roleDefinitionIdOrName: 'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Services User
      //   principalId: userAssignedIdentity.outputs.principalId
      //   principalType: 'ServicePrincipal'
      // }
    ]
  }
}

// Model deployments — serialize via @batchSize(1) to avoid CognitiveServices
// throttling. Deployed against the OpenAI account.
@batchSize(1)
module model_deployments './modules/ai/ai-foundry-model-deployment.bicep' = [for (modelDep, i) in aiModelDeployments: {
  name: take('module.model-deployment-${i}.${solutionName}', 64)
  params: {
    aiServicesAccountName: openAi.outputs.name
    deploymentName: modelDep.name
    modelName: modelDep.model
    modelVersion: modelDep.version
    raiPolicyName: modelDep.raiPolicyName
    skuName: modelDep.sku.name
    skuCapacity: modelDep.sku.capacity
  }
}]

module ai_search './modules/ai/ai-search.bicep' = {
  name: take('module.ai-search.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    skuName: enableScalability ? 'standard' : 'basic'
    replicaCount: enableRedundancy ? 3 : 1
    partitionCount: enableScalability ? 2 : 1
    publicNetworkAccess: 'Enabled' // WAF: keep public for pod access; RBAC gates auth
    diagnosticSettings: monitoringDiagnosticSettings
    roleAssignments: [
      // DKM SAI migration: UAI grant removed. Kubelet RBAC defined at end of file.
      // {
      //   roleDefinitionIdOrName: '8ebe5a00-799e-43f5-93ac-243d3dce84a7' // Search Index Data Contributor
      //   principalId: userAssignedIdentity.outputs.principalId
      //   principalType: 'ServicePrincipal'
      // }
    ]
    privateEndpoints: enablePrivateNetworking ? [
      {
        name: 'pep-srch-${solutionSuffix}'
        customNetworkInterfaceName: 'nic-srch-${solutionSuffix}'
        subnetResourceId: virtualNetwork!.outputs.backendSubnetResourceId
        service: 'searchService'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              name: 'config-search'
              privateDnsZoneResourceId: privateDnsZoneDeployments[dnsZoneIndex.search]!.outputs.resourceId
            }
          ]
        }
      }
    ] : []
  }
}

// ============================================================================
// Module: Data (Storage + Cosmos)
// ============================================================================

module storage_account './modules/data/storage-account.bicep' = {
  name: take('module.storage-account.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    publicNetworkAccess: 'Enabled' // WAF: keep public for pod queue/blob access; RBAC gates auth
    networkAcls: { defaultAction: 'Allow', bypass: 'AzureServices' }
    diagnosticSettings: monitoringDiagnosticSettings
    containers: [
      { name: 'default', publicAccess: 'None' }
      { name: 'smemory', publicAccess: 'None' }
    ]
    roleAssignments: [
      // DKM SAI migration: UAI grant removed. Kubelet RBAC defined at end of file.
      // {
      //   roleDefinitionIdOrName: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
      //   principalId: userAssignedIdentity.outputs.principalId
      //   principalType: 'ServicePrincipal'
      // }
    ]
    enablePrivateNetworking: enablePrivateNetworking
    privateEndpointSubnetId: enablePrivateNetworking ? virtualNetwork!.outputs.backendSubnetResourceId : ''
    privateDnsZoneResourceIds: enablePrivateNetworking ? [
      privateDnsZoneDeployments[dnsZoneIndex.blob]!.outputs.resourceId
    ] : []
  }
}

module cosmosDbModule './modules/data/cosmos-db-mongo.bicep' = {
  name: take('module.cosmos-db-mongo.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    name: cosmosName
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    databaseName: 'DPS'
    collections: [
      {
        name: 'ChatHistory'
        indexes: [
          { key: { keys: ['_id'] } }
        ]
        shardKey: { _id: 'Hash' }
      }
      {
        name: 'Documents'
        indexes: [
          { key: { keys: ['_id'] } }
        ]
        shardKey: { _id: 'Hash' }
      }
    ]
    publicNetworkAccess: 'Enabled' // WAF: keep public for pod access; RBAC gates auth
    diagnosticSettings: monitoringDiagnosticSettings
    zoneRedundant: enableRedundancy
    enableAutomaticFailover: enableRedundancy
    haLocation: cosmosDbHaLocation
    // WAF: Cosmos PE disabled — when PE exists, Cosmos enforces PE-only access but AKS pods
    // resolve via public DNS (PE DNS zone has no A record for the account), causing "blocked
    // by network firewall". Keep public access + RBAC for security. Matches Agentic SA pattern.
    enablePrivateNetworking: false
    privateEndpointSubnetId: ''
    privateDnsZoneResourceIds: []
  }
}

// Toolkit's cosmos-db-mongo output is credential-less. Use listConnectionStrings()
// on the deployed account to get the real connection string with embedded key
// (matches bicep flavor behavior; required for App Configuration keyValues).
resource cosmosDbExisting 'Microsoft.DocumentDB/databaseAccounts@2025-10-15' existing = {
  name: cosmosName
  dependsOn: [cosmosDbModule]
}

// ============================================================================
// Module: Compute (AKS + ACR)
// ============================================================================

module aks './modules/compute/kubernetes.bicep' = {
  name: take('module.kubernetes.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    name: aksName
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    logAnalyticsWorkspaceResourceId: enableMonitoring ? logAnalyticsWorkspaceResourceId : ''
    diagnosticSettings: monitoringDiagnosticSettings
    roleAssignments: [
      // DKM SAI migration: UAI grant removed (intentionally NOT replaced with
      // kubelet Contributor on AKS — that would let pods modify the cluster
      // itself, a privilege escalation). Kubelet least-privilege data-plane
      // grants are defined at end of file.
      // {
      //   roleDefinitionIdOrName: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
      //   principalId: userAssignedIdentity.outputs.principalId
      //   principalType: 'ServicePrincipal'
      // }
    ]
  }
}

// DKM SAI migration: workload identity outputs (kubelet objectId + control-plane
// systemAssignedMIPrincipalId) are now surfaced directly by our AKS wrapper
// (./modules/compute/kubernetes.bicep). The existing-resource workaround that
// previously dug into raw ARM properties is no longer needed.
//
// resource aksClusterExisting 'Microsoft.ContainerService/managedClusters@2025-03-01' existing = {
//   name: aksName
//   dependsOn: [aks]
// }

module containerRegistry './modules/compute/container-registry.bicep' = {
  name: take('module.container-registry.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    sku: enablePrivateNetworking ? 'Premium' : 'Premium'
    publicNetworkAccess: 'Enabled'
    // Keep ACR firewall open: Docker push from laptop (PS1) + AKS kubelet pull both need public access.
    // PE still exists for optimized in-VNet pulls. Matches Agentic SA reference pattern.
    networkRuleSetDefaultAction: 'Allow'
    acrPullPrincipalIds: [
      aks.outputs.kubeletIdentityObjectId
    ]
    acrPushPrincipalIds: [
      deployingUserPrincipalId
    ]
    acrPushPrincipalType: deployingUserPrincipalType
    enablePrivateNetworking: enablePrivateNetworking
    privateEndpointSubnetId: enablePrivateNetworking ? virtualNetwork!.outputs.backendSubnetResourceId : ''
    privateDnsZoneResourceIds: enablePrivateNetworking ? [
      privateDnsZoneDeployments[dnsZoneIndex.containerRegistry]!.outputs.resourceId
    ] : []
  }
}

// ============================================================================
// Module: App Configuration (must come last — depends on most other outputs)
// ============================================================================

var keyValues = [
  {
    name: 'ApplicationInsights:ConnectionString'
    value: enableMonitoring ? app_insights!.outputs.connectionString : ''
  }
  { name: 'Application:AIServices:GPT-4o-mini:Endpoint', value: openAi.outputs.endpoint }
  { name: 'Application:AIServices:GPT-4o-mini:ModelName', value: gptModelName }
  { name: 'Application:Services:KernelMemory:Endpoint', value: 'http://kernelmemory-service' }
  { name: 'Application:Services:PersistentStorage:CosmosMongo:Collections:ChatHistory:Collection', value: 'ChatHistory' }
  { name: 'Application:Services:PersistentStorage:CosmosMongo:Collections:ChatHistory:Database', value: 'DPS' }
  { name: 'Application:Services:PersistentStorage:CosmosMongo:Collections:DocumentManager:Collection', value: 'Documents' }
  { name: 'Application:Services:PersistentStorage:CosmosMongo:Collections:DocumentManager:Database', value: 'DPS' }
  { name: 'Application:Services:PersistentStorage:CosmosMongo:ConnectionString', value: cosmosDbExisting.listConnectionStrings().connectionStrings[0].connectionString }
  { name: 'Application:Services:AzureAISearch:Endpoint', value: ai_search.outputs.endpoint }
  { name: 'KernelMemory:Services:AzureAIDocIntel:Auth', value: 'AzureIdentity' }
  { name: 'KernelMemory:Services:AzureAIDocIntel:Endpoint', value: documentIntelligence.outputs.endpoint }
  { name: 'KernelMemory:Services:AzureAISearch:Auth', value: 'AzureIdentity' }
  { name: 'KernelMemory:Services:AzureAISearch:Endpoint', value: ai_search.outputs.endpoint }
  { name: 'KernelMemory:Services:AzureBlobs:Account', value: storage_account.outputs.name }
  { name: 'KernelMemory:Services:AzureBlobs:Auth', value: 'AzureIdentity' }
  { name: 'KernelMemory:Services:AzureBlobs:Container', value: 'smemory' }
  { name: 'KernelMemory:Services:AzureOpenAIEmbedding:Auth', value: 'AzureIdentity' }
  { name: 'KernelMemory:Services:AzureOpenAIEmbedding:Deployment', value: embeddingModelName }
  { name: 'KernelMemory:Services:AzureOpenAIEmbedding:Endpoint', value: openAi.outputs.endpoint }
  { name: 'KernelMemory:Services:AzureOpenAIText:Auth', value: 'AzureIdentity' }
  { name: 'KernelMemory:Services:AzureOpenAIText:Deployment', value: gptModelName }
  { name: 'KernelMemory:Services:AzureOpenAIText:Endpoint', value: openAi.outputs.endpoint }
  { name: 'KernelMemory:Services:AzureQueues:Account', value: storage_account.outputs.name }
  { name: 'KernelMemory:Services:AzureQueues:Auth', value: 'AzureIdentity' }
]

module appConfiguration './modules/data/app-configuration.bicep' = {
  name: take('module.app-configuration.${solutionName}', 64)
  params: {
    solutionName: solutionSuffix
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    disableLocalAuth: false // ARM needs local auth to write keyValues during deploy (matches Agentic SA pattern)
    keyValues: keyValues
    roleAssignments: [
      // DKM SAI migration: UAI grant removed. Kubelet RBAC defined at end of file.
    ]
    enablePrivateNetworking: enablePrivateNetworking
    privateEndpointSubnetId: enablePrivateNetworking ? virtualNetwork!.outputs.backendSubnetResourceId : ''
    privateDnsZoneResourceIds: enablePrivateNetworking ? [
      privateDnsZoneDeployments[dnsZoneIndex.appConfig]!.outputs.resourceId
    ] : []
    // Keep public access for ARM keyValues writes. PE still used by pods at runtime.
    publicNetworkAccess: 'Enabled'
  }
}

// ============================================================================
// DKM SAI migration: kubelet RBAC
// ============================================================================
// All data-plane grants previously held by the standalone workload UAI
// (now removed) are reassigned here to the AKS kubelet system-assigned
// identity. Pods consume this identity at runtime via DefaultAzureCredential
// → IMDS (172.17.0.1 / 169.254.169.254) — no clientId in code, no
// azure.workload.identity/use annotation on pods.
//
// Grants are RG-scoped standalone roleAssignments (not inline on each AVM
// module's roleAssignments[]) so that Storage / OpenAI / DI / Search /
// AppConfig do NOT get forced to wait for AKS to provision (~10 min cost).
// Bicep infers dependsOn from .outputs.name references on each target
// module + aks.outputs.kubeletIdentityObjectId.
//
// GUID salt matches infra/bicep/modules/identity/role-assignments.bicep so
// both flavors converge on identical assignment names.

// ============================================================================
// DKM SAI migration: AKS kubelet identity → data-plane RBAC
// ============================================================================
// REVERTED: Pods running with bare `new DefaultAzureCredential()` cannot use
// the kubelet UAI via IMDS when multiple UAIs are attached to the VMSS (IMDS
// returns HTTP 400 "Multiple user assigned identities exist"). The actual
// runtime identity is the VMSS SystemAssigned identity bootstrapped by
// Deployment/resourcedeployment.ps1 (post-deploy step). The kubelet RBAC
// grants below are preserved (commented) for reference / future re-enable if
// the workload migrates to Workload Identity or sets AZURE_CLIENT_ID.
/*
resource dkmAksKubeletStorageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, storageAccountName, aksName, 'Storage Blob Data Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: aks.outputs.kubeletIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletStorageQueueDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, storageAccountName, aksName, 'Storage Queue Data Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
    principalId: aks.outputs.kubeletIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletOpenAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, openAiAccountName, aksName, 'Cognitive Services OpenAI User')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
    principalId: aks.outputs.kubeletIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletDocIntelUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, docIntelAccountName, aksName, 'Cognitive Services User')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
    principalId: aks.outputs.kubeletIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiSearchName, aksName, 'Search Index Data Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7')
    principalId: aks.outputs.kubeletIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiSearchName, aksName, 'Search Service Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0')
    principalId: aks.outputs.kubeletIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletAppConfigDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, appConfigName, aksName, 'App Configuration Data Reader')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '516239f1-63e1-4d78-a4de-a74fb236a071')
    principalId: aks.outputs.kubeletIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}
*/

// ============================================================================
// Outputs (kept name-compatible with infra/main.bicep so azd env vars match)
// ============================================================================

@description('Contains Azure Tenant ID.')
output AZURE_TENANT_ID string = subscription().tenantId

@description('Contains Solution Name.')
output SOLUTION_NAME string = solutionSuffix

@description('Contains Resource Group Name.')
output RESOURCE_GROUP_NAME string = resourceGroup().name

@description('Contains Resource Group Location.')
output RESOURCE_GROUP_LOCATION string = location

@description('Contains Resource Group ID.')
output AZURE_RESOURCE_GROUP_ID string = resourceGroup().id

@description('WAF deployment type.')
output DEPLOYMENT_TYPE string = enablePrivateNetworking ? 'WAF' : 'Non-WAF'

@description('Contains Azure App Configuration Name.')
output AZURE_APP_CONFIG_NAME string = appConfiguration.outputs.name

@description('Contains Azure App Configuration Endpoint.')
output AZURE_APP_CONFIG_ENDPOINT string = appConfiguration.outputs.endpoint

@description('Contains Storage Account Name.')
output STORAGE_ACCOUNT_NAME string = storage_account.outputs.name

@description('Contains Cosmos DB Name.')
output AZURE_COSMOSDB_NAME string = cosmosDbModule.outputs.name

@description('Contains Cognitive Service (Document Intelligence) Name.')
output AZURE_COGNITIVE_SERVICE_NAME string = documentIntelligence.outputs.name

@description('Contains Azure Cognitive Service (Document Intelligence) Endpoint.')
output AZURE_COGNITIVE_SERVICE_ENDPOINT string = documentIntelligence.outputs.endpoint

@description('Contains Azure Search Service Name.')
output AZURE_SEARCH_SERVICE_NAME string = ai_search.outputs.name

@description('Contains Azure AKS Name.')
output AZURE_AKS_NAME string = aks.outputs.name

@description('Contains Azure AKS Managed Identity Principal ID.')
output AZURE_AKS_MI_ID string = aks.outputs.systemAssignedMIPrincipalId

@description('Contains Azure Container Registry Name.')
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name

@description('Contains Azure OpenAI Service Name.')
output AZURE_OPENAI_SERVICE_NAME string = openAi.outputs.name

@description('Contains Azure OpenAI Service Endpoint.')
output AZURE_OPENAI_SERVICE_ENDPOINT string = openAi.outputs.endpoint

@description('Contains Azure Search Service Endpoint.')
output AZ_SEARCH_SERVICE_ENDPOINT string = ai_search.outputs.endpoint

@description('Contains Azure GPT Model Deployment Name.')
output AZ_GPT4O_MODEL_ID string = gptModelName

@description('Contains Azure GPT Model Name.')
output AZ_GPT4O_MODEL_NAME string = gptModelName

@description('Contains Azure OpenAI Embedding Model Name.')
output AZ_GPT_EMBEDDING_MODEL_NAME string = embeddingModelName

@description('Contains Azure OpenAI Embedding Model Deployment Name.')
output AZ_GPT_EMBEDDING_MODEL_ID string = embeddingModelName

@description('Contains Application Insights Connection String.')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = enableMonitoring ? app_insights!.outputs.connectionString : ''

@description('Contains Application Insights Instrumentation Key.')
output APPLICATIONINSIGHTS_INSTRUMENTATION_KEY string = enableMonitoring ? app_insights!.outputs.instrumentationKey : ''

@description('Contains Application Insights Name.')
output APPLICATIONINSIGHTS_NAME string = enableMonitoring ? app_insights!.outputs.name : ''
