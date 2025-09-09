@description('Suffix to create unique resource names; 4-6 characters. Default is a random 6 characters.')
@minLength(4)
@maxLength(6)
param suffix string = substring(newGuid(), 0, 6)

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

@description('''
PLEASE CHOOSE A SECURE AND SECRET KEY ! -
Kernel Memory Service Authorization AccessKey 1.
The value is stored as an environment variable and is required by the web service to authenticate HTTP requests.
''')
@minLength(32)
@maxLength(128)
@secure()
param WebServiceAuthorizationKey1 string

@description('''
PLEASE CHOOSE A SECURE AND SECRET KEY ! -
Kernel Memory Service Authorization AccessKey 2.
The value is stored as an environment variable and is required by the web service to authenticate HTTP requests.
''')
@minLength(32)
@maxLength(128)
@secure()
param WebServiceAuthorizationKey2 string

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
param enableMonitoring bool = false

@description('Optional. Enable redundancy for applicable resources, aligned with the Well Architected Framework recommendations. Defaults to false.')
param enableRedundancy bool = false

@description('Optional. Enable scalability for applicable resources, aligned with the Well Architected Framework recommendations. Defaults to false.')
param enableScalability bool = false

@description('Optional. Enable purge protection for the Key Vault')
param enablePurgeProtection bool = false

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
var replicaLocation = replicaRegionPairs[resourceGroup().location]

@description('Optional. The Container Registry hostname where the docker images for the container app are located.')
param containerRegistryHostname string = 'biabcontainerreg.azurecr.io'

@description('Optional. The Container Image Name to deploy on the container app.')
param containerImageName string = 'macaebackend'

@description('Optional. The Container Image Tag to deploy on the container app.')
param containerImageTag string = 'latest_2025-07-22_895'

// Extracts subscription, resource group, and workspace name from the resource ID when using an existing Log Analytics workspace
var useExistingLogAnalytics = !empty(existingLogAnalyticsWorkspaceId)
var logAnalyticsWorkspaceResourceId = useExistingLogAnalytics
  ? existingLogAnalyticsWorkspaceId
  : logAnalyticsWorkspace!.outputs.resourceId

var rg = resourceGroup()

var location = resourceGroup().location

var chatGpt = {
  modelName: 'gpt-35-turbo-16k'
  deploymentName: 'chat'
  deploymentVersion: '0613'
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
      name: 'Standard'
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
      name: 'Standard'
      capacity: embedding.deploymentCapacity
    }
  }
]

// ========== Private DNS Zones ========== //
var privateDnsZones = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
  'privatelink.contentunderstanding.ai.azure.com'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.queue.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.api.azureml.ms'
  'privatelink.notebooks.azure.net'
  'privatelink.mongo.cosmos.azure.com'
  'privatelink.azconfig.io'
  'privatelink.vaultcore.azure.net'
  'privatelink.azurecr.io'
  'privatelink${environment().suffixes.sqlServerHostname}'
  'privatelink.azurewebsites.net'
  'privatelink.search.windows.net'
]
// DNS Zone Index Constants
var dnsZoneIndex = {
  cognitiveServices: 0
  openAI: 1
  aiServices: 2
  contentUnderstanding: 3
  storageBlob: 4
  storageQueue: 5
  storageFile: 6
  aiFoundry: 7
  notebooks: 8
  cosmosDB: 9
  appConfig: 10
  keyVault: 11
  containerRegistry: 12
  sqlServer: 13
  appService: 14
  search: 15
  formRecognizer: 16
}
@batchSize(5)
module avmPrivateDnsZones 'br/public:avm/res/network/private-dns-zone:0.7.1' = [
  for (zone, i) in privateDnsZones: if (enablePrivateNetworking) {
    name: 'dns-zone-${i}'
    params: {
      name: zone
      tags: tags
      enableTelemetry: enableTelemetry
      virtualNetworkLinks: [{ virtualNetworkResourceId: network.outputs.subnetPrivateEndpointsResourceId }]
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
var logAnalyticsWorkspaceResourceName = 'log-${suffix}'
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = if (enableMonitoring) {
  name: take('avm.res.operational-insights.workspace.${logAnalyticsWorkspaceResourceName}', 64)
  params: {
    name: logAnalyticsWorkspaceResourceName
    tags: tags
    location: location
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

module network 'modules/network.bicep' = if (enablePrivateNetworking) {
  name: take('network-${suffix}-deployment', 64)
  params: {
    resourcesName: suffix
    logAnalyticsWorkSpaceResourceId: logAnalyticsWorkspaceResourceId
    vmAdminUsername: vmAdminUsername ?? 'JumpboxAdminUser'
    vmAdminPassword: vmAdminPassword ?? 'JumpboxAdminP@ssw0rd1234!'
    vmSize: vmSize ?? 'Standard_DS2_v2' // Default VM size 
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
  }
}


// ========== AVM WAF ========== //
// ========== User Assigned Identity ========== //
// WAF best practices for identity and access management: https://learn.microsoft.com/en-us/azure/well-architected/security/identity-access
var userAssignedIdentityResourceName = 'id-${suffix}'
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: take('avm.res.managed-identity.user-assigned-identity.${userAssignedIdentityResourceName}', 64)
  params: {
    name: userAssignedIdentityResourceName
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
  }
}


// ========== AVM WAF ========== //
// ========== Storage account module ========== //

var storageAccountName = 'storage-${suffix}'
module avmStorageAccount 'br/public:avm/res/storage/storage-account:0.20.0' = {
  name: take('avm.res.storage.storage-account.${storageAccountName}', 64)
  params : {
    name: storageAccountName
    location: location
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
            name: 'pep-blob-${suffix}'
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
            name: 'pep-queue-${suffix}'
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
var aiSearchName = 'srch-${suffix}'
// var aiSearchConnectionName = 'myCon-${suffix}'
// var varKvSecretNameAzureSearchKey = 'AZURE-SEARCH-KEY'
// AI Foundry: AI Search
module avmSearchSearchServices 'br/public:avm/res/search/search-service:0.9.1' = {
  name: take('avm.res.cognitive-search-services.${aiSearchName}', 64)
  params: {
    name: aiSearchName
    tags: tags
    location: aiDeploymentsLocation
    enableTelemetry: enableTelemetry
    diagnosticSettings: enableMonitoring ? [{ workspaceResourceId: logAnalyticsWorkspaceResourceId }] : null
    sku: 'standard3'
    managedIdentities: { userAssignedResourceIds: [userAssignedIdentity!.outputs.resourceId] }
    replicaCount: 1
    partitionCount: 1

    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Cognitive Services Contributor' // Cognitive Search Contributor
        principalId: userAssignedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'//'5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'// Cognitive Services OpenAI User
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


// ========== AVM WAF ========== //
// ========== Cognitive Services - OpenAI module ========== //

var openAiAccountName = 'openai-${suffix}'
module avmOpenAi 'br/public:avm/res/cognitive-services/account:0.13.2' = {
  name: take('avm.res.cognitiveservices.account.${openAiAccountName}', 64)
  params: {
    name: openAiAccountName
    location: location
    kind: 'OpenAI'
    sku: 'S0'
    tags: tags
    enableTelemetry: enableTelemetry

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
            name: 'pep-openai-${suffix}'
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

// ========== AVM WAF ========== //
// ========== Cognitive Services - docIntel module ========== //

// Document Intelligence (Form Recognizer)
var docIntelAccountName = 'docIntel-${suffix}'

module docIntel 'br/public:avm/res/cognitive-services/account:0.13.2' = {
  name: take('avm.res.cognitiveservices.account.${docIntelAccountName}', 64)
  scope: rg
  params: {
    name: docIntelAccountName
    location: location
    kind: 'FormRecognizer'
    tags: tags
    sku: 'S0'
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
            name: 'pep-docintel-${suffix}'
            subnetResourceId: network.outputs.subnetPrivateEndpointsResourceId
            service: 'account'
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: [
                {
                  name: 'docintel-dns-zone-group'
                  privateDnsZoneResourceId: avmPrivateDnsZones[dnsZoneIndex.formRecognizer]!.outputs.resourceId
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


// ========== AVM WAF ========== //
// ========== Container App module ========== //

var containerAppResourceName = 'ca-${suffix}'
module containerApp 'br/public:avm/res/app/container-app:0.18.1' = {
  name: take('avm.res.app.container-app.${containerAppResourceName}', 64)
  params: {
    name: containerAppResourceName
    tags: tags
    location: location
    enableTelemetry: enableTelemetry
    environmentResourceId: containerAppEnvironment.outputs.resourceId
    managedIdentities: { systemAssigned: true }
    ingressTargetPort: 8000
    ingressExternal: true
    activeRevisionsMode: 'Single'
    // corsPolicy: {
    //   allowedOrigins: [
    //     'https://${webSiteName}.azurewebsites.net'
    //     'http://${webSiteName}.azurewebsites.net'
    //   ]
    // }
    // WAF aligned configuration for Scalability
    scaleSettings: {
      maxReplicas: enableScalability ? 3 : 1
      minReplicas: enableScalability ? 2 : 1
      rules: [
        {
          name: 'http-scaler'
          http: {
            metadata: {
              concurrentRequests: '100'
            }
          }
        }
      ]
    }
    containers: [
      {
        name: 'backend'
        image: '${containerRegistryHostname}/${containerImageName}:${containerImageTag}'
        resources: {
          cpu: '2.0'
          memory: '4.0Gi'
        }
        env: [
          {
            name: '{ENVIRONMENT_VARIABLE_NAME}'
            value: '{ENVIRONMENT_VARIABLE_VALUE}'
          }
        ]
      }
    ]
  }
}

var containerAppEnvironmentResourceName = 'cae-${suffix}'
module containerAppEnvironment 'br/public:avm/res/app/managed-environment:0.11.2' = {
  name: take('avm.res.app.managed-environment.${containerAppEnvironmentResourceName}', 64)
  params: {
    name: containerAppEnvironmentResourceName
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    publicNetworkAccess: 'Enabled'
    internal: false
    // WAF aligned configuration for Private Networking
    infrastructureSubnetResourceId: enablePrivateNetworking ? network.?outputs.?subnetResourceIds[3] : null

    // WAF aligned configuration for Monitoring
    appLogsConfiguration: enableMonitoring
      ? {
          destination: 'log-analytics'
          logAnalyticsConfiguration: {
            customerId: logAnalyticsWorkspace!.outputs.logAnalyticsWorkspaceId
            sharedKey: logAnalyticsWorkspace!.outputs!.primarySharedKey
          }
        }
      : null
    appInsightsConnectionString: enableMonitoring ? applicationInsights!.outputs.connectionString : null
    // WAF aligned configuration for Redundancy
    zoneRedundant: enableRedundancy ? true : false
    infrastructureResourceGroupName: enableRedundancy ? '${resourceGroup().name}-infra' : null
    workloadProfiles: enableRedundancy
      ? [
          {
            maximumCount: 3
            minimumCount: 3
            name: 'CAW01'
            workloadProfileType: 'D4'
          }
        ]
      : [
          {
            name: 'Consumption'
            workloadProfileType: 'Consumption'
          }
        ]
  }
}

// ========== Application Insights ========== //
var applicationInsightsResourceName = 'appi-${suffix}'
module applicationInsights 'br/public:avm/res/insights/component:0.6.0' = if (enableMonitoring) {
  name: take('avm.res.insights.component.${applicationInsightsResourceName}', 64)
  params: {
    name: applicationInsightsResourceName
    tags: tags
    location: location
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

@description('Contains Solution Name.')
output SOLUTION_NAME string = suffix

@description('Contains Resource Group Name.')
output RESOURCE_GROUP_NAME string = resourceGroup().name

@description('Contains Resource Group Location.')
output RESOURCE_GROUP_LOCATION string = location

// @description('The FQDN of the frontend web app service.')
// output kmServiceEndpoint string = containerAppService.outputs.kmServiceFQDN

// @description('Service Access Key 1.')
// output kmServiceAccessKey1 string = containerAppService.outputs.kmServiceAccessKey1

// @description('Service Access Key 2.')
// output kmServiceAccessKey2 string = containerAppService.outputs.kmServiceAccessKey2
