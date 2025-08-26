targetScope = 'resourceGroup'

@description('Required. Suffix to create unique resource names; 4-15 characters.')
@minLength(4)
@maxLength(15)
param suffix string = uniqueString(resourceGroup().id)

@description('Required. Contains Resource Group Location.')
param location string = resourceGroup().location

@description('Required. Contains Managed Identity ID.')
param managedIdentityId string

@description('Required. Contains Managed Identity Client ID.')
param managedIdentityClientId string

@description('Required. Contains KM Service Name.')
param kmServiceName string = 'km-service-${suffix}'

@description('Required. Contains Container App Environment ID.')
param containerAppsEnvironmentId string

@description('Required. Contains AppInsights Instrumentation Key.')
param appInsightsInstrumentationKey string

@description('Required. Contains App Insights Connection String.')
param applicationInsightsConnectionString string

@description('Required. Contains Azure Blobs Account.')
param AzureBlobs_Account string

@description('Required. Contains Azure Queues Account.')
param AzureQueues_Account string

@description('Required. Contains Azure Queues Queue Name.')
param AzureQueues_QueueName string

@description('Required. Contains Azure AI Search Endpoint.')
param AzureAISearch_Endpoint string

@description('Required. Contains Azure OpenAI Text Endpoint.')
param AzureOpenAIText_Endpoint string

@description('Required. Contains Azure OpenAI Text Deployment.')
param AzureOpenAIText_Deployment string

@description('Required. Contains Azure OpenAI Embedding Endpoint.')
param AzureOpenAIEmbedding_Endpoint string

@description('Required. Contains Azure OpenAI Embedding Deployment.')
param AzureOpenAIEmbedding_Deployment string

@description('Required. Contains Azure AI DocIntel Endpoint.')
param AzureAIDocIntel_Endpoint string

@description('Required. Contains Kernel Memory AccessKey 1.')
param KernelMemory__ServiceAuthorization__AccessKey1 string

@description('Required. Contains Kernel Memory AccessKey 2.')
param KernelMemory__ServiceAuthorization__AccessKey2 string

@description('Optional. Tags to be applied to the resources.')
param tags object = {}

resource kmService 'Microsoft.App/containerApps@2023-05-01' = {
  name: kmServiceName
  location: location
  properties: {
    environmentId: containerAppsEnvironmentId
    configuration: {
      secrets: [
        {
          name: 'appinsights-key'
          value: appInsightsInstrumentationKey
        }
      ]
      registries: []
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        transport: 'Auto'
        allowInsecure: false
        targetPort: 9001
        stickySessions: {
          affinity: 'none'
        }
        // additionalPortMappings: []
      }
    }

    template: {
      containers: [
        {
          name: 'kernelmemory-service'
          image: 'docker.io/kernelmemory/service:latest'
          command: []
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: applicationInsightsConnectionString
            }

            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentityClientId
            }
            {
              name: 'KernelMemory__Service__OpenApiEnabled'
              value: 'true'
            }
            {
              name: 'KernelMemory__DocumentStorageType'
              value: 'AzureBlobs'
            }
            {
              name: 'KernelMemory__TextGeneratorType'
              value: 'AzureOpenAIText'
            }
            {
              name: 'KernelMemory__DefaultIndexName'
              value: 'default'
            }
            {
              name: 'KernelMemory__ServiceAuthorization__Enabled'
              value: 'true'
            }
            {
              name: 'KernelMemory__ServiceAuthorization__AuthenticationType'
              value: 'APIKey'
            }
            {
              name: 'KernelMemory__ServiceAuthorization__HttpHeaderName'
              value: 'Authorization'
            }
            {
              name: 'KernelMemory__ServiceAuthorization__AccessKey1'
              value: KernelMemory__ServiceAuthorization__AccessKey1
            }
            {
              name: 'KernelMemory__ServiceAuthorization__AccessKey2'
              value: KernelMemory__ServiceAuthorization__AccessKey2
            }
            {
              name: 'KernelMemory__DataIngestion__DistributedOrchestration__QueueType'
              value: 'AzureQueues'
            }
            {
              name: 'KernelMemory__DataIngestion__EmbeddingGeneratorTypes__0'
              value: 'AzureOpenAIEmbedding'
            }
            {
              name: 'KernelMemory__DataIngestion__MemoryDbTypes__0'
              value: 'AzureAISearch'
            }
            {
              name: 'KernelMemory__DataIngestion__ImageOcrType'
              value: 'AzureAIDocIntel'
            }
            {
              name: 'KernelMemory__Retrieval__EmbeddingGeneratorType'
              value: 'AzureOpenAIEmbedding'
            }
            {
              name: 'KernelMemory__Retrieval__MemoryDbType'
              value: 'AzureAISearch'
            }
            {
              name: 'KernelMemory__Services__AzureBlobs__Account'
              value: AzureBlobs_Account
            }
            {
              name: 'KernelMemory__Services__AzureQueues__Account'
              value: AzureQueues_Account
            }
            {
              name: 'KernelMemory__Services__AzureQueues__QueueName'
              value: AzureQueues_QueueName
            }
            {
              name: 'KernelMemory__Services__AzureAISearch__Endpoint'
              value: AzureAISearch_Endpoint
            }
            {
              name: 'KernelMemory__Services__AzureOpenAIText__Endpoint'
              value: AzureOpenAIText_Endpoint
            }
            {
              name: 'KernelMemory__Services__AzureOpenAIText__Deployment'
              value: AzureOpenAIText_Deployment
            }
            {
              name: 'KernelMemory__Services__AzureOpenAIEmbedding__Endpoint'
              value: AzureOpenAIEmbedding_Endpoint
            }
            {
              name: 'KernelMemory__Services__AzureOpenAIEmbedding__Deployment'
              value: AzureOpenAIEmbedding_Deployment
            }
            {
              name: 'KernelMemory__Services__AzureAIDocIntel__Endpoint'
              value: AzureAIDocIntel_Endpoint
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  tags : tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
}

@description('Contains KM Service Name.')
output kmServiceName string = kmService.name

@description('Contains KM Service ID.')
output kmServiceId string = kmService.id

@description('Contains KM Service AccessKey 1.')
output kmServiceAccessKey1 string = KernelMemory__ServiceAuthorization__AccessKey1

@description('Contains KM Service AccessKey 2.')
output kmServiceAccessKey2 string = KernelMemory__ServiceAuthorization__AccessKey2

@description('The FQDN of the frontend web app service.')
output kmServiceFQDN string = kmService.properties.configuration.ingress.fqdn
