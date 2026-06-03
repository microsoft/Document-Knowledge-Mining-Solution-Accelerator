// ============================================================================
// Module: User-Assigned Managed Identity (AVM)
// Description: AVM wrapper for a User-Assigned Managed Identity.
// AVM Module: avm/res/managed-identity/user-assigned-identity:0.5.0
// ============================================================================

targetScope = 'resourceGroup'

@description('Required. Solution suffix used to derive the identity name.')
param solutionSuffix string

@description('Optional. Azure region for the identity.')
param location string = resourceGroup().location

@description('Optional. Tags to apply to the identity.')
param tags object = {}

@description('Optional. Enable usage telemetry for the AVM module.')
param enableTelemetry bool = true

var identityName = 'id-${solutionSuffix}'

module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.0' = {
  name: take('avm.res.managed-identity.user-assigned-identity.${identityName}', 64)
  params: {
    name: identityName
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
  }
}

@description('Resource ID of the User-Assigned Managed Identity.')
output resourceId string = identity.outputs.resourceId

@description('Name of the User-Assigned Managed Identity.')
output name string = identity.outputs.name

@description('Principal ID (object ID) of the identity.')
output principalId string = identity.outputs.principalId

@description('Client ID of the identity.')
output clientId string = identity.outputs.clientId
