// ========== user-assigned-identity.bicep ========== //
// Creates a User-Assigned Managed Identity. Raw (non-AVM) counterpart of
// `infra/avm/modules/identity/user-assigned-identity.bicep`.

targetScope = 'resourceGroup'

@description('Required. The name of the solution suffix used to derive the identity name.')
param solutionSuffix string

@description('Optional. Azure region where the identity will be deployed.')
param location string = resourceGroup().location

@description('Optional. Tags to apply to the identity.')
param tags object = {}

var identityName = 'id-${solutionSuffix}'

// ========== User-Assigned Managed Identity ========== //
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: identityName
  location: location
  tags: tags
}

// ========== Outputs ========== //
@description('Resource ID of the user-assigned managed identity.')
output resourceId string = userAssignedIdentity.id

@description('Name of the user-assigned managed identity.')
output name string = userAssignedIdentity.name

@description('Client ID of the managed identity.')
output clientId string = userAssignedIdentity.properties.clientId

@description('Principal (object) ID of the managed identity.')
output principalId string = userAssignedIdentity.properties.principalId

@description('Tenant ID of the managed identity.')
output tenantId string = userAssignedIdentity.properties.tenantId
