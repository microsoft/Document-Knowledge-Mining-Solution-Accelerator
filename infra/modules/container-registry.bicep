metadata name = 'Container Registry Module'
// AVM-compliant Azure Container Registry deployment

@description('The name of the Azure Container Registry')
param acrName string

@description('The location of the Azure Container Registry')
param location string

@description('SKU for the Azure Container Registry')
param acrSku string = 'Basic'

@description('Public network access setting for the Azure Container Registry')
param publicNetworkAccess string = 'Enabled'

@description('Zone redundancy setting for the Azure Container Registry')
param zoneRedundancy string = 'Disabled'

import { roleAssignmentType } from 'br/public:avm/utl/types/avm-common-types:0.7.0'
@description('Optional. Array of role assignments to create.')
param roleAssignments roleAssignmentType[]?

@description('The default action of allow or deny when no other rules match. Note: networkRuleSet is only supported for Premium SKU.')
param networkRuleSetDefaultAction string = 'Allow'

@description('Tags to be applied to the Container Registry')
param tags object = {}

module avmContainerRegistry 'br/public:avm/res/container-registry/registry:0.12.0' = {
  name: acrName
  params: {
    name: acrName
    location: location
    acrSku: acrSku
    publicNetworkAccess: publicNetworkAccess
    zoneRedundancy: zoneRedundancy
    networkRuleSetDefaultAction: networkRuleSetDefaultAction
    roleAssignments: roleAssignments
    tags: tags
  }
}

output name string = avmContainerRegistry.outputs.name
output resourceId string = avmContainerRegistry.outputs.resourceId
output loginServer string = avmContainerRegistry.outputs.loginServer
