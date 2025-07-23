// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

targetScope = 'resourceGroup'

@minLength(3)
@maxLength(20)
@description('A unique prefix for all resources in this deployment. This should be 3-20 characters long:')
param environmentName string

@description('The Data Center where the model is deployed.')
param modeldatacenter string

@description('Azure data center region where resources will be deployed. This should be a valid Azure region, e.g., eastus, westus, etc.')
param location string

var uniqueId = toLower(uniqueString(subscription().id, environmentName, location))
var resourceprefix = padLeft(take(uniqueId, 10), 10, '0')
var resourceprefix_name = 'kmgs'

var resourceGroupLocation = resourceGroup().location

// Load the abbrevations file required to name the azure resources.
var abbrs = loadJsonContent('./abbreviations.json')


// Create a storage account
module gs_storageaccount 'bicep/azurestorageaccount.bicep' = {
  name: '${abbrs.storage.storageAccount}${resourceprefix_name}${resourceprefix}'
  scope: resourceGroup()
  params: {
    storageAccountName: '${abbrs.storage.storageAccount}${resourceprefix}'
    location: resourceGroupLocation
  }
}

// Create a Azure Search Service
module gs_azsearch 'bicep/azuresearch.bicep' = {
  name: '${abbrs.ai.aiSearch}${resourceprefix_name}${resourceprefix}'
  scope: resourceGroup()
  params: {
    searchServiceName: '${abbrs.ai.aiSearch}${resourceprefix}'
    location: resourceGroupLocation
  }
}


// Create Container Registry
module gs_containerregistry 'bicep/azurecontainerregistry.bicep' = {
  name: '${abbrs.containers.containerRegistry}${resourceprefix_name}${resourceprefix}'
  scope: resourceGroup()
  params: {
    acrName: '${abbrs.containers.containerRegistry}${resourceprefix_name}${resourceprefix}'
    location: resourceGroupLocation
  }
}

// Create AKS Cluster
module gs_aks 'bicep/azurekubernetesservice.bicep' = {
  name: '${abbrs.compute.arcEnabledKubernetesCluster}${resourceprefix_name}${resourceprefix}'
  scope: resourceGroup()
  params: {
    aksName: '${abbrs.compute.arcEnabledKubernetesCluster}${resourceprefix_name}${resourceprefix}'
    location: resourceGroupLocation
  }
  dependsOn: [
    gs_containerregistry
  ]
}

// Assign ACR Pull role to AKS
// module gs_roleassignacrpull 'bicep/azureroleassignacrpull.bicep' = {
//   name: 'assignAcrPullRole'
//   scope: gs_resourcegroup
//   params: {
//     aksName: gs_aks.outputs.createdAksName
//     acrName: gs_containerregistry.outputs.createdAcrName
//   }
//   dependsOn: [
//     gs_aks
//     gs_containerregistry
//   ]
// }


// Create Azure Cognitive Service
module gs_azcognitiveservice 'bicep/azurecognitiveservice.bicep' = {
  name: '${abbrs.ai.documentIntelligence}${resourceprefix_name}${resourceprefix}'
  scope: resourceGroup()
  params: {
    cognitiveServiceName: '${abbrs.ai.documentIntelligence}${resourceprefix_name}${resourceprefix}'
    location: 'eastus'
  }
}

// Create Azure Open AI Service
module gs_openaiservice 'bicep/azureopenaiservice.bicep' = {
  name: '${abbrs.ai.openAIService}${resourceprefix_name}${resourceprefix}'
  scope: resourceGroup()
  params: {
    openAIServiceName: '${abbrs.ai.openAIService}${resourceprefix_name}${resourceprefix}'
    // GPT-4-32K model & GPT-4o available Data center information.
    // https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models#gpt-4    
    location: modeldatacenter
  }
}

// Due to limited of Quota, not easy to control per each model deployment.
// Set the minimum capacity of each model
// Based on customer's Model capacity, it needs to be updated in Azure Portal.
module gs_openaiservicemodels_gpt4o 'bicep/azureopenaiservicemodel.bicep' = {
  scope: resourceGroup()
  name: 'gpt-4o-mini'
  params: {
    parentResourceName: gs_openaiservice.outputs.openAIServiceName
    name:'gpt-4o-mini'
    model: {
        name: 'gpt-4o-mini'
        version: '2024-07-18'
        raiPolicyName: ''
        capacity: 1
        scaleType: 'Standard'
      }
    
  }
  dependsOn: [
    gs_openaiservice
  ]
}

module gs_openaiservicemodels_text_embedding 'bicep/azureopenaiservicemodel.bicep' = {
  scope: resourceGroup()
  name: 'text-embedding-large'
  params: {
    parentResourceName: gs_openaiservice.outputs.openAIServiceName
    name:'text-embedding-large'
    model: {
        name: 'text-embedding-3-large'
        version: '1'
        raiPolicyName: ''
        capacity: 1
        scaleType: 'Standard'
      }
    }
    dependsOn: [
      gs_openaiservicemodels_gpt4o
    ]  
}

// Create Azure Cosmos DB Mongo
module gs_cosmosdb 'bicep/azurecosmosdb.bicep' = {
  name: '${abbrs.databases.cosmosDBDatabase}${resourceprefix_name}${resourceprefix}'
  scope: resourceGroup()
  params: {
    cosmosDbAccountName: '${abbrs.databases.cosmosDBDatabase}${resourceprefix_name}${resourceprefix}'
    location: resourceGroupLocation
  }
}

// Create Azure App Configuration
module gs_appconfig 'bicep/azureappconfigservice.bicep' = {
  name: 'appconfig-${resourceprefix_name}${resourceprefix}'
  scope: resourceGroup()
  params: {
    appConfigName: 'appconfig-${resourceprefix_name}${resourceprefix}'
    location: resourceGroupLocation
  }
}

// return all resource names as a output
// output gs_resourcegroup_name string = '${abbrs.managementGovernance.resourceGroup}${resourceprefix_name}${resourceprefix}'
output gs_resourcegroup_name string = resourceGroup().name
output gs_solution_prefix string = '${resourceprefix_name}${resourceprefix}'
output gs_storageaccount_name string = gs_storageaccount.outputs.storageAccountName
output gs_azsearch_name string = gs_azsearch.outputs.searchServiceName

output gs_aks_name string = gs_aks.outputs.createdAksName
output gs_aks_serviceprincipal_id string = gs_aks.outputs.createdServicePrincipalId

output gs_containerregistry_name string = gs_containerregistry.outputs.createdAcrName

output gs_azcognitiveservice_name string = gs_azcognitiveservice.outputs.cognitiveServiceName
output gs_azcognitiveservice_endpoint string = gs_azcognitiveservice.outputs.cognitiveServiceEndpoint

output gs_openaiservice_name string = gs_openaiservice.outputs.openAIServiceName
output gs_openaiservice_location string = gs_openaiservice.outputs.oopenAIServiceLocation
output gs_openaiservice_endpoint string = gs_openaiservice.outputs.openAIServiceEndpoint

output gs_openaiservicemodels_gpt4o_model_name string = gs_openaiservicemodels_gpt4o.outputs.deployedModelName
output gs_openaiservicemodels_gpt4o_model_id string = gs_openaiservicemodels_gpt4o.outputs.deployedModelId

output gs_openaiservicemodels_text_embedding_model_name string = gs_openaiservicemodels_text_embedding.outputs.deployedModelName
output gs_openaiservicemodels_text_embedding_model_id string = gs_openaiservicemodels_text_embedding.outputs.deployedModelId
output gs_cosmosdb_name string = gs_cosmosdb.outputs.cosmosDbAccountName

output gs_appconfig_id string = gs_appconfig.outputs.appConfigId
output gs_appconfig_endpoint string = gs_appconfig.outputs.appConfigEndpoint

// return acr url
output gs_containerregistry_endpoint string = gs_containerregistry.outputs.acrEndpoint

//return resourcegroup resource ID
output gs_resourcegroup_id string = resourceGroup().id

