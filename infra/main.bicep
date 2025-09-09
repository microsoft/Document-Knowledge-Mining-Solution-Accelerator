// ========== main.bicep ========== //
targetScope = 'resourceGroup'

@minLength(3)
@maxLength(20)
@description('Required. A unique prefix for all resources in this deployment. This should be 3-20 characters long:')
param solutionName string = 'kmgs'

@description('Optional. Azure location for the solution. If not provided, it defaults to the resource group location.')
param location string = ''

@maxLength(5)
@description('Optional. A unique token for the solution. This is used to ensure resource names are unique for global resources. Defaults to a 5-character substring of the unique string generated from the subscription ID, resource group name, and solution name.')
param solutionUniqueToken string = substring(uniqueString(subscription().id, resourceGroup().name, solutionName), 0, 5)

var solutionSuffix= toLower(trim(replace(
  replace(
    replace(replace(replace(replace('${solutionName}${solutionUniqueToken}', '-', ''), '_', ''), '.', ''), '/', ''),
    ' ',
    ''
  ),
  '*',
  ''
)))

@description('''
gpt-35-turbo-16k deployment model\'s Tokens-Per-Minute (TPM) capacity, measured in thousands.
The default capacity is 30,000 TPM. 
For model limits specific to your region, refer to the documentation at https://learn.microsoft.com/azure/ai-services/openai/concepts/models#standard-deployment-model-quota.
''')
@minValue(1)
@maxValue(40)
param chatGptDeploymentCapacity int = 30

@description('''
text-embedding-ada-002 deployment model\'s Tokens-Per-Minute (TPM) capacity, measured in thousands.
The default capacity is 30,000 TPM.
For model limits specific to your region, refer to the documentation at https://learn.microsoft.com/azure/ai-services/openai/concepts/models#standard-deployment-model-quota.
''')
@minValue(1)
@maxValue(40)
param embeddingDeploymentCapacity int = 30

@description('Optional. The tags to apply to all deployed Azure resources.')
param tags resourceInput<'Microsoft.Resources/resourceGroups@2025-04-01'>.tags = {}

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

@description('Optional. Enable private networking for applicable resources, aligned with the WAF recommendations. Defaults to false.')
param enablePrivateNetworking bool = false

@description('Optional: Existing Log Analytics Workspace Resource ID')
param existingLogAnalyticsWorkspaceId string = ''

@description('Optional. Admin username for the Jumpbox Virtual Machine. Set to custom value if enablePrivateNetworking is true.')
@secure()
param vmAdminUsername string?

@description('Optional. Admin password for the Jumpbox Virtual Machine. Set to custom value if enablePrivateNetworking is true.')
@secure()
param vmAdminPassword string?

@description('Optional. Size of the Jumpbox Virtual Machine when created. Set to custom value if enablePrivateNetworking is true.')
param vmSize string = 'Standard_DS2_v2'

@description('Optional. Enable monitoring applicable resources, aligned with the Well Architected Framework recommendations. This setting enables Application Insights and Log Analytics and configures all the resources applicable resources to send logs. Defaults to false.')
param enableMonitoring bool = true

@description('Optional. Enable redundancy for applicable resources, aligned with the Well Architected Framework recommendations. Defaults to false.')
param enableRedundancy bool = false

@description('Optional. Enable scalability for applicable resources, aligned with the Well Architected Framework recommendations. Defaults to false.')
param enableScalability bool = false

@description('Optional. Enable purge protection for the Key Vault')
param enablePurgeProtection bool = false

@minLength(1)
@description('Optional. Name of the Text Embedding model to deploy:')
@allowed([
  'text-embedding-ada-002'
])
param embeddingModel string = 'text-embedding-ada-002'

@description('Optional. Contains Azure GPT 40 Model Name.')
param azureGpt40ModelName string = ''

var solutionLocation = empty(location) ? resourceGroup().location : location

// @description('Optional. Key vault reference and secret settings for the module\'s secrets export.')
// param secretsExportConfiguration secretsExportConfigurationType?
// Replica regions list based on article in [Azure regions list](https://learn.microsoft.com/azure/reliability/regions-list) and [Enhance resilience by replicating your Log Analytics workspace across regions](https://learn.microsoft.com/azure/azure-monitor/logs/workspace-replication#supported-regions) for supported regions for Log Analytics Workspace.
var replicaRegionPairs = {
  australiaeast: 'australiasoutheast'
  centralus: 'westus'
  eastasia: 'japaneast'
  eastus: 'centralus'
  eastus2: 'centralus'
  japaneast: 'eastasia'
  northeurope: 'westeurope'
  southeastasia: 'eastasia'
  uksouth: 'westeurope'
  westeurope: 'northeurope'
}
var replicaLocation = replicaRegionPairs[solutionLocation]

@description('Optional. The Container Registry hostname where the docker images for the container app are located.')
param containerRegistryHostname string = 'biabcontainerreg.azurecr.io'

@description('Optional. The Container Image Name to deploy on the container app.')
param containerImageName string = 'macaebackend'

@description('Optional. The Container Image Tag to deploy on the container app.')
param containerImageTag string = 'latest_2025-07-22_895'

// Extracts subscription, resource group, and workspace name from the resource ID when using an existing Log Analytics workspace
var useExistingLogAnalytics = !empty(existingLogAnalyticsWorkspaceId)

var chatGpt = {
  modelName: 'gpt-4.1-mini'
  deploymentName: 'chat'
  deploymentVersion: '2025-04-14'
  deploymentCapacity: chatGptDeploymentCapacity
}

var embedding = {
  modelName: 'text-embedding-ada-002'
  deploymentName: 'embedding'
  deploymentVersion: '2'
  deploymentCapacity: embeddingDeploymentCapacity
}

var openAiDeployments = [
  {
    name: chatGpt.deploymentName
    model: {
      format: 'OpenAI'
      name: chatGpt.modelName
      version: chatGpt.deploymentVersion
    }
    sku: {
      name: 'GlobalStandard'
      capacity: chatGpt.deploymentCapacity
    }
  }
  {
    name: embedding.deploymentName
    model: {
      format: 'OpenAI'
      name: embedding.modelName
      version: embedding.deploymentVersion
    }
    sku: {
      name: 'GlobalStandard'
      capacity: embedding.deploymentCapacity
    }
  }
]

// ========== Private DNS Zones ========== //
var privateDnsZones = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com' // Todo: to be deleted
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.queue.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}' // Todo: to be deleted
  'privatelink.api.azureml.ms'
  'privatelink.mongo.cosmos.azure.com'
  'privatelink.azconfig.io'
  'privatelink.vaultcore.azure.net' // Todo: to be deleted
  'privatelink.azurecr.io' // Todo: to be deleted
  'privatelink.search.windows.net'
]
// DNS Zone Index Constants
var dnsZoneIndex = {
  cognitiveServices: 0
  openAI: 1
  aiServices: 2
  storageBlob: 3
  storageQueue: 4
  storageFile: 5
  aiFoundry: 6
  cosmosDB: 7
  appConfig: 8
  keyVault: 9
  containerRegistry: 10
  search: 11
}
@batchSize(5)
module avmPrivateDnsZones 'br/public:avm/res/network/private-dns-zone:0.7.1' = [
  for (zone, i) in privateDnsZones: if (enablePrivateNetworking) {
    name: 'dns-zone-${i}'
    params: {
      name: zone
      tags: tags
      enableTelemetry: enableTelemetry
      virtualNetworkLinks: [{ virtualNetworkResourceId: network!.outputs.vnetResourceId }]
    }
  }
]

@metadata({
  azd: {
    type: 'location'
    usageName: [
      'OpenAI.GlobalStandard.gpt-4o-mini,150'
      'OpenAI.GlobalStandard.text-embedding-ada-002,80'
    ]
  }
})
@description('Required. Location for AI Foundry deployment. This is the location where the AI Foundry resources will be deployed.')
param aiDeploymentsLocation string

// ========== Log Analytics Workspace ========== //
// WAF best practices for Log Analytics: https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-log-analytics
// WAF PSRules for Log Analytics: https://azure.github.io/PSRule.Rules.Azure/en/rules/resource/#azure-monitor-logs
var logAnalyticsWorkspaceResourceName = 'log-${solutionSuffix}'
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = if (enableMonitoring && !useExistingLogAnalytics) {
  name: take('avm.res.operational-insights.workspace.${logAnalyticsWorkspaceResourceName}', 64)
  params: {
    name: logAnalyticsWorkspaceResourceName
    tags: tags
    location: solutionLocation
    enableTelemetry: enableTelemetry
    skuName: 'PerGB2018'
    dataRetention: 365
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
    diagnosticSettings: [{ useThisWorkspace: true }]
    // WAF aligned configuration for Redundancy
    dailyQuotaGb: enableRedundancy ? 10 : null //WAF recommendation: 10 GB per day is a good starting point for most workloads
    replication: enableRedundancy
      ? {
          enabled: true
          location: replicaLocation
        }
      : null
    // WAF aligned configuration for Private Networking
    publicNetworkAccessForIngestion: enablePrivateNetworking ? 'Disabled' : 'Enabled'
    publicNetworkAccessForQuery: enablePrivateNetworking ? 'Disabled' : 'Enabled'
    dataSources: enablePrivateNetworking
      ? [
          {
            tags: tags
            eventLogName: 'Application'
            eventTypes: [
              {
                eventType: 'Error'
              }
              {
                eventType: 'Warning'
              }
              {
                eventType: 'Information'
              }
            ]
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
          {
            kind: 'IISLogs'
            name: 'sampleIISLog1'
            state: 'OnPremiseEnabled'
          }
        ]
      : null
  }
}
var logAnalyticsWorkspaceResourceId = useExistingLogAnalytics ? existingLogAnalyticsWorkspaceId : logAnalyticsWorkspace!.outputs.resourceId

module network 'modules/network.bicep' = if (enablePrivateNetworking) {
  name: take('network-${solutionSuffix}-deployment', 64)
  params: {
    resourcesName: solutionSuffix
    logAnalyticsWorkSpaceResourceId: logAnalyticsWorkspaceResourceId
    vmAdminUsername: vmAdminUsername ?? 'JumpboxAdminUser'
    vmAdminPassword: vmAdminPassword ?? 'JumpboxAdminP@ssw0rd1234!'
    vmSize: vmSize ?? 'Standard_DS2_v2' // Default VM size 
    location: solutionLocation
    tags: tags
    enableTelemetry: enableTelemetry
  }
}

// ========== User Assigned Identity ========== //
// WAF best practices for identity and access management: https://learn.microsoft.com/en-us/azure/well-architected/security/identity-access
var userAssignedIdentityResourceName = 'id-${solutionSuffix}'
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: take('avm.res.managed-identity.user-assigned-identity.${userAssignedIdentityResourceName}', 64)
  params: {
    name: userAssignedIdentityResourceName
    location: solutionLocation
    tags: tags
    enableTelemetry: enableTelemetry
  }
}

// ========== Container Registry ========== //
module avmContainerRegistry './modules/container-registry.bicep' = {
  //name: format(deployment_param.resource_name_format_string, abbrs.containers.containerRegistry)
  params: {
    acrName: 'cr${replace(solutionSuffix, '-', '')}'
    location: solutionLocation
    acrSku: 'Standard'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
    roleAssignments: [
      {
        principalId: managedCluster.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'AcrPull'
        principalType: 'ServicePrincipal'
      }
    ]
    tags: tags
  }
}

// ========== Cosmos Database for Mongo DB ========== //
module avmCosmosDB 'br/public:avm/res/document-db/database-account:0.15.0' = {
  name: take('avm.res.cosmos-${solutionSuffix}', 64)
  params: {
    name: 'cosmos-${solutionSuffix}'
    location: solutionLocation
    mongodbDatabases: [
      {
        name: 'default'
        tag: 'default database'
      }
    ]
    tags: tags
    enableTelemetry: enableTelemetry
    databaseAccountOfferType: 'Standard'
    automaticFailover: false
    serverVersion: '7.0'
    capabilitiesToAdd: [
      'EnableMongo'
    ]
    enableAnalyticalStorage: true
    defaultConsistencyLevel: 'Session'
    maxIntervalInSeconds: 5
    maxStalenessPrefix: 100
    zoneRedundant: false

    // WAF related parameters
    networkRestrictions: {
      publicNetworkAccess: (enablePrivateNetworking) ? 'Disabled' : 'Enabled'
      ipRules: []
      virtualNetworkRules: []
    }

    privateEndpoints: (enablePrivateNetworking)
      ? [
          {
            name: 'cosmosdb-private-endpoint-${solutionSuffix}'
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: [
                {
                  privateDnsZoneResourceId: avmPrivateDnsZones[dnsZoneIndex.cosmosDB].outputs.resourceId
                }
              ]
            }
            service: 'MongoDB'
            subnetResourceId: network!.outputs.subnetPrivateEndpointsResourceId // Use the backend subnet
          }
        ]
      : []
  }
}

// ========== App Configuration store ========== //
var appConfigName = 'appcs-${solutionSuffix}'
module avmAppConfig 'br/public:avm/res/app-configuration/configuration-store:0.6.3' = {
  name: take('avm.res.app-configuration.configuration-store.${appConfigName}', 64)
  params: {
    name: appConfigName
    location: solutionLocation
    managedIdentities: { systemAssigned: true }
    sku: 'Standard'
    enableTelemetry: enableTelemetry
    tags: tags

    roleAssignments: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'App Configuration Data Reader'
        principalType: 'ServicePrincipal'
      }
    ]

    // WAF aligned networking
    publicNetworkAccess: enablePrivateNetworking ? 'Disabled' : 'Enabled'
    privateEndpoints: enablePrivateNetworking
      ? [
          {
            name: 'pep-appconfig-${solutionSuffix}'
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: [
                {
                  name: 'appconfig-dns-zone-group'
                  privateDnsZoneResourceId: avmPrivateDnsZones[dnsZoneIndex.appConfig].outputs.resourceId
                }
              ]
            }
            subnetResourceId: network!.outputs.subnetPrivateEndpointsResourceId
          }
        ]
      : []
  }
}

// ========== Storage account module ========== //

var storageAccountName = 'st${solutionSuffix}'
module avmStorageAccount 'br/public:avm/res/storage/storage-account:0.20.0' = {
  name: take('avm.res.storage.storage-account.${storageAccountName}', 64)
  params : {
    name: storageAccountName
    location: solutionLocation
    managedIdentities: { systemAssigned: true }
    minimumTlsVersion: 'TLS1_2'
    enableTelemetry: enableTelemetry
    tags: tags
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true

    roleAssignments: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
        principalType: 'ServicePrincipal'
      }
    ]

    // WAF aligned networking
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: enablePrivateNetworking ? 'Deny' : 'Allow'
    }
    allowBlobPublicAccess: enablePrivateNetworking ? true : false
    publicNetworkAccess: enablePrivateNetworking ? 'Disabled' : 'Enabled'

    privateEndpoints: enablePrivateNetworking
      ? [
          {
            name: 'pep-blob-${solutionSuffix}'
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: [
                {
                  name: 'storage-dns-zone-group-blob'
                  privateDnsZoneResourceId: avmPrivateDnsZones[dnsZoneIndex.storageBlob]!.outputs.resourceId
                }
              ]
            }
            subnetResourceId: network.outputs.subnetPrivateEndpointsResourceId
            service: 'blob'
          }
          {
            name: 'pep-queue-${solutionSuffix}'
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: [
                {
                  name: 'storage-dns-zone-group-queue'
                  privateDnsZoneResourceId: avmPrivateDnsZones[dnsZoneIndex.storageQueue]!.outputs.resourceId
                }
              ]
            }
            subnetResourceId: network.outputs.subnetPrivateEndpointsResourceId
            service: 'queue'
          }
        ]
      : []

      blobServices: {
      corsRules: []
      deleteRetentionPolicyEnabled: false
      containers: [
        {
          name: 'data'
          publicAccess: 'None'
        }
      ]
    }
  }
}

// ========== AI Foundry: AI Search ========== //
var aiSearchName = 'srch-${solutionSuffix}'
// var aiSearchConnectionName = 'myCon-${solutionSuffix}'
// var varKvSecretNameAzureSearchKey = 'AZURE-SEARCH-KEY'
// AI Foundry: AI Search
module avmSearchSearchServices 'br/public:avm/res/search/search-service:0.9.1' = {
  name: take('avm.res.cognitive-search-services.${aiSearchName}', 64)
  params: {
    name: aiSearchName
    tags: tags
    location: solutionLocation
    enableTelemetry: enableTelemetry
    diagnosticSettings: enableMonitoring ? [{ workspaceResourceId: logAnalyticsWorkspaceResourceId }] : null
    sku: enableScalability ? 'standard' : 'basic'
    managedIdentities: { userAssignedResourceIds: [userAssignedIdentity!.outputs.resourceId] }
    replicaCount: 1
    partitionCount: 1
  
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Search Index Data Contributor' // Cognitive Search Contributor
        principalId: userAssignedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: 'Search Index Data Reader' //'5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'// Cognitive Services OpenAI User
        principalId: userAssignedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
    ]
    disableLocalAuth: false
    semanticSearch: 'free'
    // secretsExportConfiguration: {
    //   keyVaultResourceId: keyvault.outputs.resourceId
    //   primaryAdminKeyName: varKvSecretNameAzureSearchKey
    // }
    // WAF aligned configuration for Private Networking
    publicNetworkAccess: enablePrivateNetworking ? 'Disabled' : 'Enabled'
    privateEndpoints: enablePrivateNetworking
      ? [
          {
            name: 'pep-${aiSearchName}'
            customNetworkInterfaceName: 'nic-${aiSearchName}'
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: [
                { privateDnsZoneResourceId: avmPrivateDnsZones[dnsZoneIndex.search]!.outputs.resourceId }
              ]
            }
            subnetResourceId: network.outputs.subnetPrivateEndpointsResourceId
          }
        ]
      : []
  }
}

// // ========== Cognitive Services - OpenAI module ========== //

var openAiAccountName = 'oai-${solutionSuffix}'
module avmOpenAi 'br/public:avm/res/cognitive-services/account:0.13.2' = {
  name: take('avm.res.cognitiveservices.account.${openAiAccountName}', 64)
  params: {
    name: openAiAccountName
    location: solutionLocation
    kind: 'OpenAI'
    sku: 'S0'
    tags: tags
    enableTelemetry: enableTelemetry
    customSubDomainName: openAiAccountName
    managedIdentities: {
      systemAssigned: true
    }

    // WAF baseline
    publicNetworkAccess: enablePrivateNetworking ? 'Disabled' : 'Enabled'
    networkAcls: {
      defaultAction: enablePrivateNetworking ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
    }

    privateEndpoints: enablePrivateNetworking
      ? [
          {
            name: 'pep-openai-${solutionSuffix}'
            subnetResourceId: network.outputs.subnetPrivateEndpointsResourceId
            service: 'account'
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: [
                {
                  name: 'openai-dns-zone-group'
                  privateDnsZoneResourceId: avmPrivateDnsZones[dnsZoneIndex.openAI]!.outputs.resourceId
                }
              ]
            }
          }
        ]
      : []

    // Role assignments
    roleAssignments: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI Contributor'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
        principalType: 'ServicePrincipal'
      }
    ]

    // OpenAI deployments (pass array from main)
    deployments: openAiDeployments
  }
}

// ========== Cognitive Services - Document Intellignece module ========== //
var docIntelAccountName = 'di-${solutionSuffix}'
module documentIntelligence 'br/public:avm/res/cognitive-services/account:0.13.2' = {
  name: take('avm.res.cognitiveservices.account.${docIntelAccountName}', 64)
  params: {
    name: docIntelAccountName
    location: solutionLocation
    kind: 'FormRecognizer'
    tags: tags
    sku: 'S0'
    customSubDomainName: docIntelAccountName
    managedIdentities: {
      systemAssigned: true
    }

    // Networking aligned to WAF
    publicNetworkAccess: enablePrivateNetworking ? 'Disabled' : 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: enablePrivateNetworking ? 'Deny' : 'Allow'
    }

    // Private Endpoint for Form Recognizer
    privateEndpoints: enablePrivateNetworking
      ? [
          {
            name: 'pep-docintel-${solutionSuffix}'
            subnetResourceId: network.outputs.subnetPrivateEndpointsResourceId
            service: 'account'
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: [
                {
                  name: 'docintel-dns-zone-group'
                  privateDnsZoneResourceId: avmPrivateDnsZones[dnsZoneIndex.cognitiveServices]!.outputs.resourceId
                }
              ]
            }
          }
        ]
      : []

    // Role Assignments
    roleAssignments: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Cognitive Services User'
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// ========== Azure Kubernetes Service (AKS) ========== //
module managedCluster 'br/public:avm/res/container-service/managed-cluster:0.10.1' = {
  name: take('avm.res.container-service.managed-cluster.aks-${solutionSuffix}', 64)
  params: {
    name: 'aks-${solutionSuffix}'
    location: solutionLocation
    tags: tags
    enableTelemetry: enableTelemetry
    kubernetesVersion: '1.30.4'
    dnsPrefix: 'aks-${solutionSuffix}'
    enableRBAC: true
    disableLocalAccounts: false
    publicNetworkAccess: 'Enabled'
    managedIdentities: {
      systemAssigned: true
      // userAssignedResourceIds: [
      //   userAssignedIdentity.outputs.resourceId
      // ]
    }
    primaryAgentPoolProfiles: [
      {
        name: 'agentpool'
        vmSize: 'Standard_D4ds_v5'
        count: 2
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
      }
    ]
    roleAssignments: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Contributor'
        principalType: 'ServicePrincipal'
      }
    ]
    // WAF aligned configuration for Monitoring
    monitoringWorkspaceResourceId: enableMonitoring ? logAnalyticsWorkspaceResourceId : null
    // WAF aligned configuration for Private Networking
  }
}

// ========== Application Insights ========== //
var applicationInsightsResourceName = 'appi-${solutionSuffix}'
module applicationInsights 'br/public:avm/res/insights/component:0.6.0' = if (enableMonitoring) {
  name: take('avm.res.insights.component.${applicationInsightsResourceName}', 64)
  params: {
    name: applicationInsightsResourceName
    tags: tags
    location: solutionLocation
    enableTelemetry: enableTelemetry
    retentionInDays: 365
    kind: 'web'
    disableIpMasking: false
    flowType: 'Bluefield'
    // WAF aligned configuration for Monitoring
    workspaceResourceId: enableMonitoring ? logAnalyticsWorkspace.outputs.resourceId : ''
    diagnosticSettings: enableMonitoring ? [{ workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId }] : null
  }
}

/* 
  Outputs
*/
output AZURE_TENANT_ID string = subscription().tenantId

@description('Contains Solution Name.')
output SOLUTION_NAME string = solutionSuffix

@description('Contains Resource Group Name.')
output RESOURCE_GROUP_NAME string = resourceGroup().name

@description('Contains Resource Group Location.')
output RESOURCE_GROUP_LOCATION string = solutionLocation

output AZURE_RESOURCE_GROUP_ID string = resourceGroup().id

output AZURE_APP_CONFIG_NAME string = avmAppConfig.outputs.name

output AZURE_APP_CONFIG_ENDPOINT string = avmAppConfig.outputs.endpoint

@description('Contains Resource Group Name.')
output STORAGE_ACCOUNT_NAME string = avmStorageAccount.outputs.name

@description('Contains Cosmos DB Name.')
output AZURE_COSMOSDB_NAME string = avmCosmosDB.outputs.name

@description('Contains Cognitive Service Name.')
output AZURE_COGNITIVE_SERVICE_NAME string = documentIntelligence.outputs.name

@description('Contains Azure Cognitive Service Endpoint.')
output AZURE_COGNITIVE_SERVICE_ENDPOINT string = documentIntelligence.outputs.endpoint

@description('Contains Azure Search Service Name.')
output AZURE_SEARCH_SERVICE_NAME string = avmSearchSearchServices.outputs.name

@description('Contains Azure Search Service Name.')
output AZURE_AKS_NAME string = managedCluster.outputs.name

@description('Contains Azure Search Service Name.')
output AZURE_AKS_MI_ID string = managedCluster.outputs.systemAssignedMIPrincipalId

@description('Contains Azure Search Service Name.')
output AZURE_CONTAINER_REGISTRY_NAME string = avmContainerRegistry.outputs.name

@description('Contains Azure OpenAI Search Service Name.')
output AZURE_OPENAI_SERVICE_NAME string = avmOpenAi.outputs.name

@description('Contains Azure OpenAI Service Endpoint.')
output AZURE_OPENAI_SERVICE_ENDPOINT string = avmOpenAi.outputs.endpoint

@description('Contains Azure Search Service Endpoint.')
output AZ_SEARCH_SERVICE_ENDPOINT string = avmSearchSearchServices.outputs.name

@description('Contains Azure GPT40 Model ID.')
output AZ_GPT4O_MODEL_ID string = chatGpt.deploymentName

@description('Contains Azure OpenAI embedding model name.')
output AZ_GPT4O_MODEL_NAME string = chatGpt.modelName

@description('Contains Azure OpenAI embedding model name.')
output AZ_GPT_EMBEDDING_MODEL_NAME string = embedding.modelName

@description('Contains Azure OpenAI embedding model name.')
output AZ_GPT_EMBEDDING_MODEL_ID string = embedding.deploymentName

// @description('The FQDN of the frontend web app service.')
// output kmServiceEndpoint string = containerAppService.outputs.kmServiceFQDN

// @description('Service Access Key 1.')
// output kmServiceAccessKey1 string = containerAppService.outputs.kmServiceAccessKey1

// @description('Service Access Key 2.')
// output kmServiceAccessKey2 string = containerAppService.outputs.kmServiceAccessKey2
