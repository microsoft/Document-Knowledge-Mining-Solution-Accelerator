// ============================================================================
// Module: Document Intelligence (Form Recognizer) (AVM)
// Description: AVM wrapper for a Cognitive Services account of kind
//              FormRecognizer with an optional private endpoint.
// AVM Module: avm/res/cognitive-services/account:0.14.2
// ============================================================================

targetScope = 'resourceGroup'

@description('Required. Name of the Document Intelligence account.')
param name string

@description('Optional. Azure region for the account.')
param location string = resourceGroup().location

@description('Optional. Tags to apply.')
param tags object = {}

@description('Optional. SKU for the account.')
param sku string = 'S0'

@description('Optional. Disable local (key) authentication.')
param disableLocalAuth bool = true

@description('Optional. Custom subdomain — defaults to the account name.')
param customSubDomainName string = ''

@description('Required. Principal ID to grant Cognitive Services User role.')
param principalId string

@description('Optional. Public network access setting.')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

@description('Optional. Resource ID of the subnet for the private endpoint.')
param privateEndpointSubnetResourceId string = ''

@description('Optional. Private DNS zone resource ID for cognitiveservices.')
param cognitiveServicesPrivateDnsZoneResourceId string = ''

@description('Optional. Create a private endpoint for the account.')
param createPrivateEndpoint bool = false

@description('Optional. Enable usage telemetry for the AVM module.')
param enableTelemetry bool = true

module documentIntelligence 'br/public:avm/res/cognitive-services/account:0.14.2' = {
  name: take('avm.res.cognitiveservices.account.${name}', 64)
  params: {
    name: name
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    kind: 'FormRecognizer'
    sku: sku
    customSubDomainName: !empty(customSubDomainName) ? customSubDomainName : name
    disableLocalAuth: disableLocalAuth
    managedIdentities: { systemAssigned: true }
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: publicNetworkAccess == 'Disabled' ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
    }
    privateEndpoints: []
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionIdOrName: 'Cognitive Services User'
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

module docIntelPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.12.0' = if (createPrivateEndpoint) {
  name: take('pep-${name}-deployment', 64)
  params: {
    name: 'pep-${name}'
    customNetworkInterfaceName: 'nic-${name}'
    location: location
    tags: tags
    subnetResourceId: privateEndpointSubnetResourceId
    privateLinkServiceConnections: [
      {
        name: 'pep-${name}-connection'
        properties: {
          privateLinkServiceId: documentIntelligence.outputs.resourceId
          groupIds: ['account']
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        { name: 'docintel-dns-zone-cognitiveservices', privateDnsZoneResourceId: cognitiveServicesPrivateDnsZoneResourceId }
      ]
    }
  }
}

@description('Resource ID of the Document Intelligence account.')
output resourceId string = documentIntelligence.outputs.resourceId

@description('Name of the Document Intelligence account.')
output name string = documentIntelligence.outputs.name

@description('Endpoint URL of the Document Intelligence account.')
output endpoint string = documentIntelligence.outputs.endpoint
