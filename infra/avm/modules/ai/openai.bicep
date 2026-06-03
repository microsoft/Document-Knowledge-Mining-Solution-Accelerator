// ============================================================================
// Module: Azure OpenAI (AVM)
// Description: AVM wrapper for an Azure OpenAI Cognitive Services account
//              with model deployments and an optional 2-DNS-zone private endpoint.
// AVM Module: avm/res/cognitive-services/account:0.14.2
// ============================================================================

targetScope = 'resourceGroup'

@description('Required. Name of the OpenAI account.')
param name string

@description('Optional. Azure region for OpenAI deployments.')
param location string = resourceGroup().location

@description('Optional. Tags to apply.')
param tags object = {}

@description('Optional. SKU for the account.')
param sku string = 'S0'

@description('Optional. Disable local (key) authentication.')
param disableLocalAuth bool = true

@description('Optional. Custom subdomain — defaults to the account name.')
param customSubDomainName string = ''

@description('Required. Principal ID to grant Cognitive Services OpenAI Contributor + User roles.')
param principalId string

@description('Required. Model deployments to provision (name/model/sku/capacity).')
param deployments array

@description('Optional. Public network access setting.')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

@description('Optional. Resource ID of the subnet for the private endpoint.')
param privateEndpointSubnetResourceId string = ''

@description('Optional. Private DNS zone resource ID for cognitiveservices.')
param cognitiveServicesPrivateDnsZoneResourceId string = ''

@description('Optional. Private DNS zone resource ID for openai.')
param openAiPrivateDnsZoneResourceId string = ''

@description('Optional. Create a private endpoint for the account.')
param createPrivateEndpoint bool = false

@description('Optional. Enable usage telemetry for the AVM module.')
param enableTelemetry bool = true

module openAi 'br/public:avm/res/cognitive-services/account:0.14.2' = {
  name: take('avm.res.cognitiveservices.account.${name}', 64)
  params: {
    name: name
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    kind: 'OpenAI'
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
    deployments: deployments
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI Contributor'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: principalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// Separate PE module so we can attach two DNS zones (cognitiveservices + openai)
module openAiPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.12.0' = if (createPrivateEndpoint) {
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
          privateLinkServiceId: openAi.outputs.resourceId
          groupIds: ['account']
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        { name: 'ai-services-dns-zone-cognitiveservices', privateDnsZoneResourceId: cognitiveServicesPrivateDnsZoneResourceId }
        { name: 'ai-services-dns-zone-openai', privateDnsZoneResourceId: openAiPrivateDnsZoneResourceId }
      ]
    }
  }
}

@description('Resource ID of the OpenAI account.')
output resourceId string = openAi.outputs.resourceId

@description('Name of the OpenAI account.')
output name string = openAi.outputs.name

@description('Endpoint URL of the OpenAI account.')
output endpoint string = openAi.outputs.endpoint
