// ============================================================================
// Module: Role Assignments (centralized — all cross-service + data plane RBAC)
// Description: RG-level, cross-service, and data-plane role assignments.
//              One place to audit "who has access to what".
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Solution name suffix for generating unique role assignment GUIDs.')
param solutionName string = ''

@description('Whether to use an existing AI project (true) or create new (false).')
param useExistingAIProject bool = false

@description('Resource ID of the existing AI project (for deriving AI Services name/sub/RG).')
param existingFoundryProjectResourceId string = ''

// --- Identity Principal IDs ---

@description('Principal ID of the AI project identity (works for both new and existing projects).')
param aiProjectPrincipalId string = ''

@description('Principal ID of the AI Search identity.')
param aiSearchPrincipalId string = ''

@description('Principal ID of the backend App Service system-assigned identity (empty if not deployed).')
param backendAppServicePrincipalId string = ''

@description('Principal ID of the deploying user (for user access roles).')
param deployerPrincipalId string = ''

@description('Principal type of the deploying user.')
@allowed(['User', 'ServicePrincipal'])
param deployerPrincipalType string = 'User'

// --- Resource References ---

@description('Resource ID of the AI Foundry account (empty if not deployed — new project path).')
param aiFoundryResourceId string = ''

@description('Resource ID of the AI Search service (empty if not deployed).')
param aiSearchResourceId string = ''

@description('Resource ID of the Storage Account (empty if not deployed).')
param storageAccountResourceId string = ''

@description('Name of the Cosmos DB account (empty if not deployed).')
param cosmosDbAccountName string = ''

// --- DKM Workload Identity (UAI + AKS kubelet) parameters ---
// NOTE: These parameters extend the toolkit-shipped module with DKM-specific
// RBAC for the workload User-Assigned Managed Identity and AKS kubelet
// identity. They are intentionally folded into this file (rather than a
// separate dkm-*.bicep overlay) per project preference. Any future toolkit
// re-sync that overwrites this file MUST re-apply this DKM block.

@description('DKM: Principal ID of the workload User-Assigned Managed Identity.')
param userAssignedIdentityPrincipalId string = ''

@description('DKM: Name of the workload User-Assigned Managed Identity (used as GUID salt for stable role-assignment names).')
param userAssignedIdentityName string = ''

@description('DKM: Principal ID of the AKS kubelet identity (for AcrPull on ACR).')
param aksKubeletPrincipalId string = ''

@description('DKM: Name of the Storage Account (UAI Storage Blob Data Contributor at RG scope).')
param storageAccountName string = ''

@description('DKM: Name of the Azure OpenAI / Cognitive Services account (UAI OpenAI Contributor + OpenAI User at RG scope).')
param openAiAccountName string = ''

@description('DKM: Name of the Document Intelligence (FormRecognizer) account (UAI Cognitive Services User at RG scope).')
param docIntelAccountName string = ''

@description('DKM: Name of the AI Search service (UAI Search Index Data Contributor at RG scope).')
param aiSearchName string = ''

@description('DKM: Name of the AKS cluster (UAI Contributor at RG scope + GUID salt for kubelet AcrPull).')
param aksClusterName string = ''

@description('DKM: Name of the Container Registry (AKS kubelet AcrPull at RG scope).')
param containerRegistryName string = ''

@description('DKM: Name of the App Configuration store (UAI App Configuration Data Reader at RG scope).')
param appConfigName string = ''

// ============================================================================
// Derived Variables
// ============================================================================

var existingAIFoundryName = useExistingAIProject ? split(existingFoundryProjectResourceId, '/')[8] : ''
var existingAIFoundrySubscription = useExistingAIProject ? split(existingFoundryProjectResourceId, '/')[2] : subscription().subscriptionId
var existingAIFoundryResourceGroup = useExistingAIProject ? split(existingFoundryProjectResourceId, '/')[4] : resourceGroup().name

// ============================================================================
// Role Definitions
// ============================================================================

var roleDefinitions = {
  azureAiUser: '53ca6127-db72-4b80-b1b0-d745d6d5456d' // Foundry User
  cognitiveServicesUser: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  cognitiveServicesOpenAIUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  cognitiveServicesOpenAIContributor: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
  searchIndexDataReader: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  searchIndexDataContributor: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  searchServiceContributor: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  storageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  storageQueueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  acrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
  appConfigDataReader: '516239f1-63e1-4d78-a4de-a74fb236a071'
}

// ============================================================================
// Existing Resource References
// ============================================================================

resource aiFoundryAccount 'Microsoft.CognitiveServices/accounts@2025-12-01' existing = if (!empty(aiFoundryResourceId)) {
  name: last(split(aiFoundryResourceId, '/'))
}

resource aiSearchService 'Microsoft.Search/searchServices@2025-05-01' existing = if (!empty(aiSearchResourceId)) {
  name: last(split(aiSearchResourceId, '/'))
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-08-01' existing = if (!empty(storageAccountResourceId)) {
  name: last(split(storageAccountResourceId, '/'))
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2025-10-15' existing = if (!empty(cosmosDbAccountName)) {
  name: cosmosDbAccountName
}

resource cosmosContributorRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2025-10-15' existing = if (!empty(cosmosDbAccountName)) {
  parent: cosmosAccount
  name: '00000000-0000-0000-0000-000000000002' // Cosmos DB Built-in Data Contributor
}

// ============================================================================
// 1. AI SERVICES ROLE ASSIGNMENTS
//    Cross-service roles scoped to AI Foundry account
// ============================================================================

// AI Search → Cognitive Services OpenAI User on AI Foundry (new project, same RG)
resource assignOpenAIRoleToAISearch 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!useExistingAIProject && !empty(aiSearchPrincipalId) && !empty(aiFoundryResourceId)) {
  name: guid(solutionName, aiFoundryAccount.id, aiSearchPrincipalId, roleDefinitions.cognitiveServicesOpenAIUser)
  scope: aiFoundryAccount
  properties: {
    principalId: aiSearchPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.cognitiveServicesOpenAIUser)
    principalType: 'ServicePrincipal'
  }
}

// AI Search → Cognitive Services OpenAI User on existing AI Foundry (cross-scope)
module assignOpenAIToSearchExisting './cross-scope-role-assignment.bicep' = if (useExistingAIProject && !empty(aiSearchPrincipalId)) {
  name: 'assignOpenAIRoleToAISearchExisting'
  scope: resourceGroup(existingAIFoundrySubscription, existingAIFoundryResourceGroup)
  params: {
    principalId: aiSearchPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.cognitiveServicesOpenAIUser)
    roleAssignmentName: guid(solutionName, existingAIFoundryName, aiSearchPrincipalId, roleDefinitions.cognitiveServicesOpenAIUser)
    aiFoundryName: existingAIFoundryName
  }
}

// Backend App Service → Foundry User on AI Foundry (new project, same RG)
resource backendAppAiUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!useExistingAIProject && !empty(aiFoundryResourceId) && !empty(backendAppServicePrincipalId)) {
  name: guid(solutionName, aiFoundryAccount.id, backendAppServicePrincipalId, roleDefinitions.azureAiUser)
  scope: aiFoundryAccount
  properties: {
    principalId: backendAppServicePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.azureAiUser)
    principalType: 'ServicePrincipal'
  }
}

// Backend App Service → Foundry User on existing AI Foundry (cross-scope)
module backendAppAiUserExisting './cross-scope-role-assignment.bicep' = if (useExistingAIProject && !empty(backendAppServicePrincipalId)) {
  name: 'assignAiUserRoleToBackendExisting'
  scope: resourceGroup(existingAIFoundrySubscription, existingAIFoundryResourceGroup)
  params: {
    principalId: backendAppServicePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.azureAiUser)
    roleAssignmentName: guid(solutionName, existingAIFoundryName, backendAppServicePrincipalId, roleDefinitions.azureAiUser)
    aiFoundryName: existingAIFoundryName
  }
}

// ============================================================================
// 2. SEARCH SERVICE ROLE ASSIGNMENTS
//    AI Project and Backend identities → AI Search
// ============================================================================

// AI Project → Search Index Data Reader on AI Search
resource projectSearchReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiSearchResourceId) && !empty(aiProjectPrincipalId)) {
  name: guid(solutionName, aiSearchService.id, aiProjectPrincipalId, roleDefinitions.searchIndexDataReader)
  scope: aiSearchService
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.searchIndexDataReader)
    principalType: 'ServicePrincipal'
  }
}

// AI Project → Search Service Contributor on AI Search
resource projectSearchContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiSearchResourceId) && !empty(aiProjectPrincipalId)) {
  name: guid(solutionName, aiSearchService.id, aiProjectPrincipalId, roleDefinitions.searchServiceContributor)
  scope: aiSearchService
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.searchServiceContributor)
    principalType: 'ServicePrincipal'
  }
}

// Backend App Service → Search Index Data Reader on AI Search
resource backendAppSearchReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiSearchResourceId) && !empty(backendAppServicePrincipalId)) {
  name: guid(solutionName, aiSearchService.id, backendAppServicePrincipalId, roleDefinitions.searchIndexDataReader)
  scope: aiSearchService
  properties: {
    principalId: backendAppServicePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.searchIndexDataReader)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// 3. STORAGE ROLE ASSIGNMENTS
//    AI Project, AI Search, and Existing Project identities → Storage
// ============================================================================

// AI Project → Storage Blob Data Contributor
resource projectStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(storageAccountResourceId) && !empty(aiProjectPrincipalId)) {
  name: guid(solutionName, storageAccount.id, aiProjectPrincipalId, roleDefinitions.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.storageBlobDataContributor)
    principalType: 'ServicePrincipal'
  }
}

// AI Project → Storage Blob Data Reader
resource projectStorageReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(storageAccountResourceId) && !empty(aiProjectPrincipalId)) {
  name: guid(solutionName, storageAccount.id, aiProjectPrincipalId, roleDefinitions.storageBlobDataReader)
  scope: storageAccount
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.storageBlobDataReader)
    principalType: 'ServicePrincipal'
  }
}

// AI Search → Storage Blob Data Reader
resource searchStorageReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(storageAccountResourceId) && !empty(aiSearchPrincipalId)) {
  name: guid(solutionName, storageAccount.id, aiSearchPrincipalId, roleDefinitions.storageBlobDataReader)
  scope: storageAccount
  properties: {
    principalId: aiSearchPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.storageBlobDataReader)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// 4. COSMOS DB ROLE ASSIGNMENTS
//    Backend App Service → Cosmos DB (data-plane, uses sqlRoleAssignments)
// ============================================================================

resource backendAppCosmosRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-10-15' = if (!empty(cosmosDbAccountName) && !empty(backendAppServicePrincipalId)) {
  parent: cosmosAccount
  name: guid(solutionName, cosmosContributorRoleDefinition.id, cosmosAccount.id, backendAppServicePrincipalId)
  properties: {
    principalId: backendAppServicePrincipalId
    roleDefinitionId: cosmosContributorRoleDefinition.id
    scope: cosmosAccount.id
  }
}

// ============================================================================
// 5. DEPLOYER (USER) ROLE ASSIGNMENTS
//    Deploying user → AI Services, Search, Storage (Bicep-only)
// ============================================================================

// Deploying User → Cognitive Services User on AI Services
resource deployerAiServicesAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!useExistingAIProject && !empty(deployerPrincipalId) && !empty(aiFoundryResourceId)) {
  scope: aiFoundryAccount
  name: guid(solutionName, aiFoundryAccount.id, deployerPrincipalId, roleDefinitions.cognitiveServicesUser)
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.cognitiveServicesUser)
    principalType: deployerPrincipalType
  }
}

// Deploying User → Foundry User on AI Services
resource deployerAzureAIAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!useExistingAIProject && !empty(deployerPrincipalId) && !empty(aiFoundryResourceId)) {
  scope: aiFoundryAccount
  name: guid(solutionName, aiFoundryAccount.id, deployerPrincipalId, roleDefinitions.azureAiUser)
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.azureAiUser)
    principalType: deployerPrincipalType
  }
}

// Deploying User → Search Index Data Contributor on AI Search
resource deployerSearchIndexContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerPrincipalId) && !empty(aiSearchResourceId)) {
  scope: aiSearchService
  name: guid(solutionName, aiSearchService.id, deployerPrincipalId, roleDefinitions.searchIndexDataContributor)
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.searchIndexDataContributor)
    principalType: deployerPrincipalType
  }
}

// Deploying User → Search Service Contributor on AI Search
resource deployerSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerPrincipalId) && !empty(aiSearchResourceId)) {
  scope: aiSearchService
  name: guid(solutionName, aiSearchService.id, deployerPrincipalId, roleDefinitions.searchServiceContributor)
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.searchServiceContributor)
    principalType: deployerPrincipalType
  }
}

// Deploying User → Storage Blob Data Contributor
resource deployerStorageBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerPrincipalId) && !empty(storageAccountResourceId)) {
  scope: storageAccount
  name: guid(solutionName, storageAccount.id, deployerPrincipalId, roleDefinitions.storageBlobDataContributor)
  properties: {
    principalId: deployerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.storageBlobDataContributor)
    principalType: deployerPrincipalType
  }
}

// NOTE: Deployer roles on existing AI Foundry (cross-scope) are assigned via
// 00_build_solution.py to avoid conflicts when the deployer already has the roles.

// ============================================================================
// 6. DKM WORKLOAD IDENTITY ROLE ASSIGNMENTS  (SAI migration)
//    Pre-migration: a standalone workload UAI (id-<solutionSuffix>) was granted
//    all data-plane roles. Post-migration: the AKS kubelet system-assigned
//    identity (auto-created by Microsoft.ContainerService/managedClusters) is
//    the runtime identity pods consume via DefaultAzureCredential → IMDS, so
//    all data-plane RBAC is now granted to that principal.
//
//    GUID names use (resourceGroup().id, <resourceName>, aksClusterName,
//    '<RoleDisplayName>') — aksClusterName is the stable salt across redeploys.
//    All blocks remain guarded by !empty() so the module is a safe no-op when
//    DKM params aren't passed (forward-compat).
//
//    The original dkmUai* blocks are commented (not deleted) for diff clarity
//    and to keep the byte-locked module folder pattern intact.
// ============================================================================

/* DKM SAI migration: workload UAI removed — kubelet identity is now the grantee.
// UAI → Storage Blob Data Contributor (RG scope)
resource dkmUaiStorageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userAssignedIdentityPrincipalId) && !empty(storageAccountName)) {
  name: guid(resourceGroup().id, storageAccountName, userAssignedIdentityName, 'Storage Blob Data Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.storageBlobDataContributor)
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// UAI → Cognitive Services OpenAI Contributor (RG scope, salted with OpenAI account name)
resource dkmUaiOpenAiContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userAssignedIdentityPrincipalId) && !empty(openAiAccountName)) {
  name: guid(resourceGroup().id, openAiAccountName, userAssignedIdentityName, 'Cognitive Services OpenAI Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.cognitiveServicesOpenAIContributor)
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// UAI → Cognitive Services OpenAI User (RG scope, salted with OpenAI account name)
resource dkmUaiOpenAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userAssignedIdentityPrincipalId) && !empty(openAiAccountName)) {
  name: guid(resourceGroup().id, openAiAccountName, userAssignedIdentityName, 'Cognitive Services OpenAI User')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.cognitiveServicesOpenAIUser)
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// UAI → Cognitive Services User (RG scope, salted with Document Intelligence account name)
resource dkmUaiDocIntelUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userAssignedIdentityPrincipalId) && !empty(docIntelAccountName)) {
  name: guid(resourceGroup().id, docIntelAccountName, userAssignedIdentityName, 'Cognitive Services User')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.cognitiveServicesUser)
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// UAI → Search Index Data Contributor (RG scope)
resource dkmUaiSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userAssignedIdentityPrincipalId) && !empty(aiSearchName)) {
  name: guid(resourceGroup().id, aiSearchName, userAssignedIdentityName, 'Search Index Data Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.searchIndexDataContributor)
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// UAI → Contributor (RG scope, salted with AKS cluster name)
resource dkmUaiAksContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userAssignedIdentityPrincipalId) && !empty(aksClusterName)) {
  name: guid(resourceGroup().id, aksClusterName, userAssignedIdentityName, 'Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.contributor)
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
*/

// AKS kubelet identity → AcrPull (RG scope, salted with container registry + AKS cluster names)
resource dkmAksKubeletAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aksKubeletPrincipalId) && !empty(containerRegistryName)) {
  name: guid(resourceGroup().id, containerRegistryName, aksClusterName, 'AcrPull')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.acrPull)
    principalId: aksKubeletPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ----------------------------------------------------------------------------
// DKM SAI migration: AKS kubelet identity → data-plane RBAC
// ----------------------------------------------------------------------------
// REVERTED: Pods running with bare `new DefaultAzureCredential()` cannot use
// the kubelet UAI via IMDS when multiple UAIs are attached to the VMSS (IMDS
// returns HTTP 400 "Multiple user assigned identities exist"). The actual
// runtime identity is the VMSS SystemAssigned identity bootstrapped by
// Deployment/resourcedeployment.ps1 (post-deploy step). The kubelet RBAC
// grants below are preserved (commented) for reference / future re-enable if
// the workload migrates to Workload Identity or sets AZURE_CLIENT_ID.
/*
resource dkmAksKubeletStorageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aksKubeletPrincipalId) && !empty(storageAccountName)) {
  name: guid(resourceGroup().id, storageAccountName, aksClusterName, 'Storage Blob Data Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.storageBlobDataContributor)
    principalId: aksKubeletPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletStorageQueueDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aksKubeletPrincipalId) && !empty(storageAccountName)) {
  name: guid(resourceGroup().id, storageAccountName, aksClusterName, 'Storage Queue Data Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.storageQueueDataContributor)
    principalId: aksKubeletPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletOpenAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aksKubeletPrincipalId) && !empty(openAiAccountName)) {
  name: guid(resourceGroup().id, openAiAccountName, aksClusterName, 'Cognitive Services OpenAI User')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.cognitiveServicesOpenAIUser)
    principalId: aksKubeletPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletDocIntelUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aksKubeletPrincipalId) && !empty(docIntelAccountName)) {
  name: guid(resourceGroup().id, docIntelAccountName, aksClusterName, 'Cognitive Services User')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.cognitiveServicesUser)
    principalId: aksKubeletPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aksKubeletPrincipalId) && !empty(aiSearchName)) {
  name: guid(resourceGroup().id, aiSearchName, aksClusterName, 'Search Index Data Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.searchIndexDataContributor)
    principalId: aksKubeletPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aksKubeletPrincipalId) && !empty(aiSearchName)) {
  name: guid(resourceGroup().id, aiSearchName, aksClusterName, 'Search Service Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.searchServiceContributor)
    principalId: aksKubeletPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource dkmAksKubeletAppConfigDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aksKubeletPrincipalId) && !empty(appConfigName)) {
  name: guid(resourceGroup().id, appConfigName, aksClusterName, 'App Configuration Data Reader')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.appConfigDataReader)
    principalId: aksKubeletPrincipalId
    principalType: 'ServicePrincipal'
  }
}
*/

/* DKM SAI migration: workload UAI removed — kubelet identity replaces it above.
// UAI → App Configuration Data Reader (RG scope)
resource dkmUaiAppConfigDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userAssignedIdentityPrincipalId) && !empty(appConfigName)) {
  name: guid(resourceGroup().id, appConfigName, userAssignedIdentityName, 'App Configuration Data Reader')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.appConfigDataReader)
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
*/

// Deployer (azd user / CI SP) → AcrPush (RG scope, salted with container registry name + deployer principal)
// Lets the principal running `azd up` push images during the post-deploy
// docker build/push step without manual `az role assignment create`.
resource dkmDeployerAcrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerPrincipalId) && !empty(containerRegistryName)) {
  name: guid(resourceGroup().id, containerRegistryName, deployerPrincipalId, 'AcrPush')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.acrPush)
    principalId: deployerPrincipalId
    principalType: deployerPrincipalType
  }
}
