@description('Required. Suffix to create unique resource names; 4-15 characters.')
@minLength(4)
@maxLength(15)
param suffix string = uniqueString(resourceGroup().id)

@description('Managed Identity name.')
@minLength(2)
@maxLength(60)
param name string = 'km-UAidentity-${suffix}'

@description('Location for all resources.')
param location string = resourceGroup().location

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${resourceGroup().id}contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b24988ac-6180-42a0-ab88-20f7382dd24c'
    )
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Contains Managed Identity ID.')
output managedIdentityId string = managedIdentity.id

@description('Contains Managed Identity Principal ID.')
output managedIdentityPrincipalId string = managedIdentity.properties.principalId

@description('Contains Managed Identity Client ID.')
output managedIdentityClientId string = managedIdentity.properties.clientId
