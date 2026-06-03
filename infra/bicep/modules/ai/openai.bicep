// ========== openai.bicep ========== //
// Creates an Azure OpenAI (Cognitive Services) account with one or more model
// deployments and role assignments. Raw (non-AVM) counterpart of
// `infra/avm/modules/ai/openai.bicep`.
//
// NOTE: The bicep flavor is public-endpoint-only by design — for private
// networking use the AVM flavor (deploymentFlavor='avm').

targetScope = 'resourceGroup'

@description('Required. Name of the OpenAI account (also used as the custom subdomain).')
param name string

@description('Optional. Azure region for the account.')
param location string = resourceGroup().location

@description('Optional. Tags to apply.')
param tags object = {}

@description('Optional. SKU for the Cognitive Services account.')
param skuName string = 'S0'

@description('Optional. Disable local (key-based) authentication. Recommended when using managed identity.')
param disableLocalAuth bool = true

@description('Optional. Principal ID of a managed identity to grant OpenAI roles to. Empty skips role assignments.')
param userAssignedPrincipalId string = ''

@description('Optional. List of model deployments to create. Each entry: { name, model: { format, name, version }, sku: { name, capacity } }.')
param deployments array = []

// ========== Cognitive Services Account (OpenAI kind) ========== //
resource openAi 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: skuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: name
    disableLocalAuth: disableLocalAuth
  }
}

// ========== Model Deployments ========== //
@batchSize(1)
resource modelDeployments 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [
  for (deployment, i) in deployments: {
    parent: openAi
    name: deployment.name
    sku: {
      name: deployment.sku.name
      capacity: deployment.sku.capacity
    }
    properties: {
      model: {
        format: deployment.model.format
        name: deployment.model.name
        version: deployment.model.version
      }
    }
  }
]

// ========== Role Assignments ========== //
var openAiContributorRoleId = 'a001fd3d-188f-4b5d-821b-7da978bf7442'
var openAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userAssignedPrincipalId)) {
  name: guid(openAi.id, userAssignedPrincipalId, openAiContributorRoleId)
  scope: openAi
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAiContributorRoleId)
    principalId: userAssignedPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource userRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userAssignedPrincipalId)) {
  name: guid(openAi.id, userAssignedPrincipalId, openAiUserRoleId)
  scope: openAi
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAiUserRoleId)
    principalId: userAssignedPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ========== Outputs ========== //
@description('Resource ID of the OpenAI account.')
output resourceId string = openAi.id

@description('Name of the OpenAI account.')
output name string = openAi.name

@description('OpenAI inference endpoint.')
output endpoint string = openAi.properties.endpoint

@description('Names of the created model deployments.')
output deploymentNames array = [for (deployment, i) in deployments: modelDeployments[i].name]
