// ========== document-intelligence.bicep ========== //
// Creates an Azure AI Document Intelligence (Cognitive Services - FormRecognizer
// kind) account. Raw (non-AVM) counterpart of
// `infra/avm/modules/ai/document-intelligence.bicep`.
//
// NOTE: The bicep flavor is public-endpoint-only by design — for private
// networking use the AVM flavor (deploymentFlavor='avm').

targetScope = 'resourceGroup'

@description('Required. Name of the Document Intelligence account (also used as the custom subdomain).')
param name string

@description('Optional. Azure region for the account.')
param location string = resourceGroup().location

@description('Optional. Tags to apply.')
param tags object = {}

@description('Optional. SKU for the Cognitive Services account.')
param skuName string = 'S0'

@description('Optional. Disable local (key-based) authentication.')
param disableLocalAuth bool = true

@description('Optional. Principal ID of a managed identity to grant Cognitive Services User to. Empty skips role assignment.')
param userAssignedPrincipalId string = ''

// ========== Cognitive Services Account (FormRecognizer kind) ========== //
resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'FormRecognizer'
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

// ========== Role Assignment ========== //
var cognitiveServicesUserRoleId = 'a97b65f3-24c7-4388-baec-2e87135dc908'

resource cognitiveUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userAssignedPrincipalId)) {
  name: guid(documentIntelligence.id, userAssignedPrincipalId, cognitiveServicesUserRoleId)
  scope: documentIntelligence
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleId)
    principalId: userAssignedPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ========== Outputs ========== //
@description('Resource ID of the Document Intelligence account.')
output resourceId string = documentIntelligence.id

@description('Name of the Document Intelligence account.')
output name string = documentIntelligence.name

@description('Document Intelligence endpoint URI.')
output endpoint string = documentIntelligence.properties.endpoint
