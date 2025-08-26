@description('Required. Suffix to create unique resource names; 4-15 characters.')
@minLength(4)
@maxLength(15)
param suffix string = uniqueString(resourceGroup().id)

@description('Required. Contains ManagedIdentity Principal ID.')
param managedIdentityPrincipalId string

metadata description = 'Creates an Azure Document Intelligence (form recognizer) instance.'

@description('Required. Contains Name.')
param name string

@description('Required. Contains Resource Group Location.')
param location string = resourceGroup().location

@description('The custom subdomain name used to access the API. Defaults to the value of the name parameter.')
param customSubDomainName string = name
param kind string = 'FormRecognizer'

@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'S0'
}

@description('Required. Contains IP Rules.')
param allowedIpRules array = []
param networkAcls object = empty(allowedIpRules)
  ? {
      defaultAction: 'Allow'
    }
  : {
      ipRules: allowedIpRules
      defaultAction: 'Deny'
    }

@description('Optional. Tags to be applied to the resources.')
param tags object = {}


resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: networkAcls
    disableLocalAuth: true
  }
  sku: sku
}

// Cognitive Services User
resource roleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('Cognitive Services User-${suffix}')
  scope: account
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'a97b65f3-24c7-4388-baec-2e87135dc908'
    )
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

@description('Contains Endpoint.')
output endpoint string = account.properties.endpoint
