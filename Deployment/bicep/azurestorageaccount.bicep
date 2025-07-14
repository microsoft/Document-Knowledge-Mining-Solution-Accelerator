@description('Name of the storage account')
param storageAccountName string

@description('Location for the storage account')
param location string = resourceGroup().location

@description('The SKU of the storage account')
param skuName string = 'Standard_LRS'

@description('The kind of the storage account')
param kind string = 'StorageV2'

@allowed([
  'TLS1_2'
  'TLS1_3'
])
@description('Optional. Set the minimum TLS version on request to storage. The TLS versions 1.0 and 1.1 are deprecated and not supported anymore.')
param minimumTlsVersion string = 'TLS1_2'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: skuName
  }
  kind: kind
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: minimumTlsVersion
  }
}

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
