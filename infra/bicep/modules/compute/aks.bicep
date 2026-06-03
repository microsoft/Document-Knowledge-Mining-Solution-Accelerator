// ========== aks.bicep ========== //
// Creates an Azure Kubernetes Service (AKS) managed cluster with a single
// system node pool, RBAC, OMS agent + Defender integration (when monitoring
// enabled), and an optional Contributor role assignment for a user-assigned
// identity. Raw (non-AVM) counterpart of `infra/avm/modules/compute/aks.bicep`.

targetScope = 'resourceGroup'

@description('Required. Name of the managed cluster.')
param name string

@description('Optional. Azure region for the cluster.')
param location string = resourceGroup().location

@description('Optional. Tags to apply.')
param tags object = {}

@description('Optional. Kubernetes version (must be a version supported in the target region).')
param kubernetesVersion string = '1.34.2'

@description('Optional. DNS prefix used by the API server endpoint.')
param dnsPrefix string = name

@description('Optional. VM size for the system node pool.')
param nodeVmSize string = 'Standard_D4ds_v5'

@description('Optional. Initial node count for the system pool.')
@minValue(1)
@maxValue(100)
param nodeCount int = 2

@description('Optional. Minimum node count for the autoscaler.')
@minValue(1)
param minNodeCount int = 1

@description('Optional. Maximum node count for the autoscaler.')
@minValue(1)
param maxNodeCount int = 2

@description('Optional. Service CIDR used by the cluster.')
param serviceCidr string = '10.20.0.0/16'

@description('Optional. DNS service IP (must be inside serviceCidr).')
param dnsServiceIP string = '10.20.0.10'

@description('Optional. Network plugin.')
@allowed(['azure', 'kubenet', 'none'])
param networkPlugin string = 'azure'

@description('Optional. Network policy.')
@allowed(['azure', 'calico', 'cilium', 'none', ''])
param networkPolicy string = 'azure'

@description('Optional. Resource ID of a Log Analytics workspace for OMS agent / diagnostics. Empty disables monitoring integrations.')
param logAnalyticsWorkspaceId string = ''

@description('Optional. Principal ID of a managed identity to grant Contributor on the cluster. Empty skips role assignment.')
param contributorPrincipalId string = ''

var enableMonitoring = !empty(logAnalyticsWorkspaceId)

// ========== AKS Managed Cluster ========== //
resource aks 'Microsoft.ContainerService/managedClusters@2024-09-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix
    enableRBAC: true
    disableLocalAccounts: false
    publicNetworkAccess: 'Enabled'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: nodeCount
        vmSize: nodeVmSize
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: true
        minCount: minNodeCount
        maxCount: maxNodeCount
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
      }
    ]
    networkProfile: {
      networkPlugin: networkPlugin
      networkPolicy: empty(networkPolicy) ? null : networkPolicy
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
      nodeOSUpgradeChannel: 'Unmanaged'
    }
    addonProfiles: enableMonitoring ? {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    } : {}
  }
}

// ========== Diagnostic Settings ========== //
resource aksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableMonitoring) {
  name: 'customSetting'
  scope: aks
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'kube-apiserver', enabled: true }
      { category: 'kube-controller-manager', enabled: true }
      { category: 'kube-scheduler', enabled: true }
      { category: 'cluster-autoscaler', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// ========== Role Assignment ========== //
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(contributorPrincipalId)) {
  name: guid(aks.id, contributorPrincipalId, contributorRoleId)
  scope: aks
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: contributorPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ========== Outputs ========== //
@description('Resource ID of the AKS managed cluster.')
output resourceId string = aks.id

@description('Name of the AKS managed cluster.')
output name string = aks.name

@description('Principal ID of the AKS cluster system-assigned identity (used to grant AcrPull on the registry).')
output systemAssignedIdentityPrincipalId string = aks.identity.principalId

@description('Principal ID of the kubelet identity (used by node pools to pull images from ACR). NOTE: equals the system-assigned identity principal ID when no kubelet identity override is configured.')
output kubeletIdentityPrincipalId string = aks.properties.identityProfile.kubeletidentity.objectId

@description('FQDN of the cluster control plane.')
output controlPlaneFqdn string = aks.properties.fqdn
