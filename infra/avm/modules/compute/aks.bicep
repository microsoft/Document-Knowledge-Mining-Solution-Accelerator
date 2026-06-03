// ============================================================================
// Module: AKS Managed Cluster (AVM)
// Description: AVM wrapper for an AKS cluster with a single system node pool,
//              optional OMS agent + Defender for Containers integration, and
//              an optional Contributor role assignment for a UAI principal.
// AVM Module: avm/res/container-service/managed-cluster:0.13.0
// ============================================================================

targetScope = 'resourceGroup'

@description('Required. Name of the managed cluster.')
param name string

@description('Optional. Azure region for the cluster.')
param location string = resourceGroup().location

@description('Optional. Tags to apply.')
param tags object = {}

@description('Optional. Kubernetes version.')
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

@description('Optional. Subnet resource ID for the agent pool. Empty omits subnet binding.')
param agentPoolSubnetResourceId string = ''

@description('Optional. Resource ID of a Log Analytics workspace. Empty disables OMS/Defender/diagnostics.')
param logAnalyticsWorkspaceId string = ''

@description('Optional. Enable Microsoft Defender for Containers. Requires logAnalyticsWorkspaceId.')
param enableDefender bool = false

@description('Optional. Principal ID of a managed identity to grant Contributor on the cluster. Empty skips.')
param contributorPrincipalId string = ''

@description('Optional. Enable usage telemetry for the AVM module.')
param enableTelemetry bool = true

var enableMonitoring = !empty(logAnalyticsWorkspaceId)

var roleAssignments = !empty(contributorPrincipalId) ? [
  {
    principalId: contributorPrincipalId
    roleDefinitionIdOrName: 'Contributor'
    principalType: 'ServicePrincipal'
  }
] : []

var diagnosticSettings = enableMonitoring ? [
  {
    name: 'customSetting'
    workspaceResourceId: logAnalyticsWorkspaceId
    logCategoriesAndGroups: [
      { category: 'kube-apiserver' }
      { category: 'kube-controller-manager' }
      { category: 'kube-scheduler' }
      { category: 'cluster-autoscaler' }
    ]
    metricCategories: [
      { category: 'AllMetrics' }
    ]
  }
] : null

var securityProfile = enableDefender && enableMonitoring ? {
  defender: {
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceId
    securityMonitoring: { enabled: true }
  }
} : {}

module managedCluster 'br/public:avm/res/container-service/managed-cluster:0.13.0' = {
  name: take('avm.res.container-service.managed-cluster.${name}', 64)
  params: {
    name: name
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix
    managedIdentities: { systemAssigned: true }
    disableLocalAccounts: false
    publicNetworkAccess: 'Enabled'
    primaryAgentPoolProfiles: [
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
        vnetSubnetResourceId: !empty(agentPoolSubnetResourceId) ? agentPoolSubnetResourceId : null
      }
    ]
    networkPlugin: networkPlugin
    networkPolicy: empty(networkPolicy) ? null : networkPolicy
    serviceCidr: serviceCidr
    dnsServiceIP: dnsServiceIP
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
      nodeOSUpgradeChannel: 'Unmanaged'
    }
    omsAgentEnabled: enableMonitoring
    monitoringWorkspaceResourceId: enableMonitoring ? logAnalyticsWorkspaceId : null
    securityProfile: securityProfile
    diagnosticSettings: diagnosticSettings
    roleAssignments: roleAssignments
  }
}

@description('Resource ID of the AKS managed cluster.')
output resourceId string = managedCluster.outputs.resourceId

@description('Name of the AKS managed cluster.')
output name string = managedCluster.outputs.name

@description('Principal ID of the AKS cluster system-assigned identity.')
output systemAssignedIdentityPrincipalId string = managedCluster.outputs.?systemAssignedMIPrincipalId ?? ''

@description('Principal ID of the kubelet identity (used by node pools to pull images from ACR).')
output kubeletIdentityPrincipalId string = managedCluster.outputs.?kubeletIdentityObjectId ?? ''

@description('FQDN of the cluster control plane.')
output controlPlaneFqdn string = managedCluster.outputs.controlPlaneFQDN
