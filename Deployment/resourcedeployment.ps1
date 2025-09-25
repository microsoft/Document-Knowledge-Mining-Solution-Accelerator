# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

#https://patorjk.com/software/taag


param (
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName
)

Write-Host "DEBUG: ResourceGroupName parameter received: '$ResourceGroupName'" -ForegroundColor Magenta

function startBanner() {
    Write-Host "  _____                                        _                                               "
    Write-Host " |  __ \                                      | |                                              "
    Write-Host " | |  | | ___   ___ _   _ _ __ ___   ___ _ __ | |_                                             "
    Write-Host " | |  | |/ _ \ / __| | | | '_ ` _ \ /  _ \ '_ \| __|                                           "
    Write-Host " | |__| | (_) | (__| |_| | | | | | |  __/ | | | |_                                             "
    Write-Host " |_____/ \___/ \___|\__,_|_| |_| |_|\___|_| |_|\__|  __  __ _       _                          "
    Write-Host " | |/ /                   | |        | |            |  \/  (_)     (_)                         "
    Write-Host " | ' / _ __   _____      _| | ___  __| | __ _  ___  | \  / |_ _ __  _ _ __   __ _              "
    Write-Host " |  < | '_ \ / _ \ \ /\ / / |/ _ \/ _`  |/ _`  |/ _ \ | |\/| | | '_ \| | '_ \ / _`  |          "
    Write-Host " | . \| | | | (_) \ V  V /| |  __/ (_| | (_| |  __/ | |  | | | | | | | | | | (_| |             "
    Write-Host " |_|\_\_| |_|\___/ \_/\_/ |_|\___|\__,_|\__, |\___| |_|  |_|_|_| |_|_|_| |_|\__, |             "
    Write-Host "   _____       _       _   _             __/ |                  _            __/ |             "
    Write-Host "  / ____|     | |     | | (_)           |___/ /\               | |          |___/ |            "
    Write-Host " | (___   ___ | |_   _| |_ _  ___  _ __      /  \   ___ ___ ___| | ___ _ __ __ _| |_ ___  _ __ "
    Write-Host "  \___ \ / _ \| | | | | __| |/ _ \| '_ \    / /\ \ / __/ __/ _ \ |/ _ \ '__/ _` | __/ _  \| '__|"
    Write-Host "  ____) | (_) | | |_| | |_| | (_) | | | |  / ____ \ (_| (_|  __/ |  __/ | | (_| | || (_) | |   "
    Write-Host " |_____/ \___/|_|\__,_|\__|_|\___/|_| |_| /_/    \_\___\___\___|_|\___|_|  \__,_|\__\___/|_|   "
    Write-Host "                                                                                               "
    Write-Host "                                                                                               "
}

#https://patorjk.com/software/taag
function successBanner(){
    Write-Host "   _____                              __       _           "
    Write-Host "  / ____|                            / _|     | |          "
    Write-Host " | (___  _   _  ___ ___ ___  ___ ___| |_ _   _| |          "
    Write-Host "  \___ \| | | |/ __/ __/ _ \/ __/ __|  _| | | | |          "
    Write-Host "  ____) | |_| | (_| (_|  __/\__ \__ \ | | |_| | |          "
    Write-Host " |_____/ \__,_|\___\___\___||___/___/_|  \__,_|_|      _   "
    Write-Host " |  __ \           | |                                | |  "
    Write-Host " | |  | | ___ _ __ | | ___  _   _ _ __ ___   ___ _ __ | |_ "
    Write-Host " | |  | |/ _ \ '_ \| |/ _ \| | | | '_ ` _ \  / _ \ '_ \| __|"
    Write-Host " | |__| |  __/ |_) | | (_) | |_| | | | | | |  __/ | | | |_ "
    Write-Host " |_____/ \___| .__/|_|\___/ \__, |_| |_| |_|\___|_| |_|\__|"
    Write-Host "             | |             __/ |                         "
    Write-Host "             |_|            |___/                          "     
}

function failureBanner(){
    Write-Host " _____             _                                  _     "
    Write-Host "|  __ \           | |                                | |    "
    Write-Host "| |  | | ___ _ __ | | ___  _   _ _ __ ___   ___ _ __ | |_   "
    Write-Host "| |  | |/ _ \ '_ \| |/ _ \| | | | '_ ` _ \ / _ \ '_ \| __|  "
    Write-Host "| |__| |  __/ |_) | | (_) | |_| | | | | | |  __/ | | | |_   "
    Write-Host "|_____/ \___| .__/|_|\___/ \__, |_| |_| |_|\___|_| |_|\__|  "
    Write-Host "            | |             __/ |                           "
    Write-Host " ______    _|_|         _  |___/                            "
    Write-Host "|  ____|  (_) |        | |                                  "
    Write-Host "| |__ __ _ _| | ___  __| |                                  "
    Write-Host "|  __/ _` | | |/ _ \/ _` |                                  "
    Write-Host "| | | (_| | | |  __/ (_| |                                  "
    Write-Host "|_|  \__,_|_|_|\___|\__,_|                                  "
}

# Common function to check if a variable is null or empty
function ValidateVariableIsNullOrEmpty {
    param (
        [string]$variableValue, 
        [string]$variableName
    )
 
    if ([string]::IsNullOrEmpty($variableValue)) {
        Write-Host "Error: $variableName is null or empty." -ForegroundColor Red
        failureBanner 
        exit 1
    }    
}
# Function to prompt for parameters with kind messages
function PromptForParameters {
    param(
        [string]$email
)
    Clear-Host

    # Display banner
    
    startBanner

    if (-not $email) {
        Write-Host "Please enter your email address for certificate management" -ForegroundColor Cyan
        $email = Read-Host -Prompt '> '
    }

    return @{
        email = $email
    }
}

# Prompt for parameters with kind messages
 $params = PromptForParameters -email $email
$email = $params.email

function LoginAzure([string]$tenantId, [string]$subscriptionID) {
    Write-Host "Log in to Azure.....`r`n" -ForegroundColor Yellow
    if ($env:CI -eq "true"){
        az login --service-principal `
            --username $env:AZURE_CLIENT_ID `
            --password $env:AZURE_CLIENT_SECRET `
            --tenant $env:AZURE_TENANT_ID `
        Write-Host "CI deployment mode"
    }
    else{
        az login --tenant $tenantId
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to log in to Azure with tenant ID '$tenantId'. Please check your credentials." -ForegroundColor Red
            failureBanner
            exit 1
        }
        else{
            Write-Host "Logged in to Azure with tenant ID '$tenantId' successfully." -ForegroundColor Green
        }
        Write-Host "manual deployment mode"
    }
    az account set --subscription $subscriptionID
    Write-Host "Switched subscription to '$subscriptionID' `r`n" -ForegroundColor Yellow  
}

function DisplayResult([DeploymentResult]$displayResult) {
    Write-Host "********************************************************************************" -ForegroundColor Blue
    Write-Host "*                 Deployed Azure Resources Information                         *" -ForegroundColor Blue
    Write-Host "********************************************************************************" -ForegroundColor Blue
    Write-Host "* Tenant Id: " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.TenantId)" -ForegroundColor Green
    Write-Host "* Subscription Id: " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.SubscriptionId)" -ForegroundColor Green
    Write-Host "* Knowledge Mining Digital Asset resource group: " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.ResourceGroupName)" -ForegroundColor Green
    Write-Host "* Azure Kubernetes Account " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.AksName)" -ForegroundColor Green
    Write-Host "* Azure Container Registry " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.AzContainerRegistryName)" -ForegroundColor Green
    Write-Host "* Azure Search Service " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.AzSearchServiceName)" -ForegroundColor Green
    Write-Host "* Azure Open AI Service " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.AzOpenAIServiceName)" -ForegroundColor Green
    Write-Host "* Azure Cognitive Service " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.AzCognitiveServiceName)" -ForegroundColor Green
    Write-Host "* Azure Storage Account " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.StorageAccountName)" -ForegroundColor Green
    Write-Host "* Azure Cosmos DB " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.AzCosmosDBName)" -ForegroundColor Green
    Write-Host "* Azure App Configuration Endpoint " -ForegroundColor Yellow -NoNewline; Write-Host "$($displayResult.AzAppConfigEndpoint)" -ForegroundColor Green
    Write-Output "rg_name=$($displayResult.ResourceGroupName)" >> $Env:GITHUB_ENV

    Write-Output "SOLUTION_PREFIX=$($displayResult.SolutionPrefix)" >> $Env:GITHUB_ENV
}

# Function to replace placeholders in a template with actual values
function Invoke-PlaceholdersReplacement($template, $placeholders) {
    foreach ($key in $placeholders.Keys) {
        $template = $template -replace $key, $placeholders[$key]
    }
    return $template
}
# Function to get the external IP address of a service
function Get-ExternalIP {
    param (
        [string]$serviceName,
        [string]$namespace
    )
    $externalIP = kubectl get svc $serviceName -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    return $externalIP
}

# Function to generate a dynamic banner
function Show-Banner {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Title
    )

    # Calculate the banner width based on the title length with padding
    $padding = 6
    $bannerWidth = $Title.Length + ($padding * 2) + 4
    $borderLine = "*" * $bannerWidth

    # Create the padded title
    $borderLength = $borderLine.Length
    $paddedTitle = "* " + (" " * $padding) + $Title + (" " * $padding) + " *"

    # Check if the title length is odd or even and adjust the padding. the boderLine width and the paddedTitle width should be the same
    if ($paddedTitle.Length -lt $borderLength) {
        $paddedTitle += " "
    } else {
        $paddedTitle = $paddedTitle.Substring(0, $bannerWidth - 1) + "*"
    }
    
    # # Check if the title length is odd or even and adjust the padding
    # if ($paddedTitle.Length -lt $borderLength) {
    #     $paddedTitle += " "
    # }
    
    # # Adjust the padded title length to match the banner width
    # $paddedTitle = $paddedTitle.Substring(0, $bannerWidth - 1) + "*"

    # Display the banner
    Write-Host $borderLine -ForegroundColor Blue
    Write-Host $paddedTitle -ForegroundColor Blue
    Write-Host $borderLine -ForegroundColor Blue
}

# Get all environment values
if (!$ResourceGroupName) {
    $envValues = azd env get-values --output json | ConvertFrom-Json
}

function Get-AzdEnvValueOrDefault {
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyName,

        [Parameter(Mandatory = $false)]
        [string]$DefaultValue = "",

        [Parameter(Mandatory = $false)]
        [bool]$Required = $false
    )

    # Check if key exists
    if ($envValues.PSObject.Properties.Name -contains $KeyName) {
        return $envValues.$KeyName
    }

     # Step 2: Try from GitHub Action environment variables (system env)
     $githubValue = [System.Environment]::GetEnvironmentVariable($KeyName, "Process")
    if ($githubValue) {
        return $githubValue
    }

    # Key doesn't exist
    if ($Required) {
        Write-Error "Required environment key '$KeyName' not found in azd environment."
        exit 1
    } else {
        return $DefaultValue
    }
}

class DeploymentResult {
    [string]$TenantId
    [string]$SubscriptionId
    [string]$ResourceGroupName
    [string]$ResourceGroupId
    [string]$StorageAccountName
    [string]$AzSearchServiceName
    [string]$AzSearchServicEndpoint
    [string]$AksName
    [string]$AksMid
    [string]$AzContainerRegistryName
    [string]$AzCognitiveServiceName
    [string]$AzCognitiveServiceEndpoint
    [string]$AzOpenAiServiceName
    [string]$AzGPT4oModelName
    [string]$AzGPT4oModelId
    [string]$AzGPTEmbeddingModelName
    [string]$AzGPTEmbeddingModelId
    [string]$AzOpenAiServiceEndpoint
    [string]$AzCosmosDBName
    [string]$AzCosmosDBConnectionString
    [string]$AzAppConfigEndpoint
    [string]$AzAppConfigName

    DeploymentResult() {
        # Resource Group
        $this.TenantId = ""
        $this.SubscriptionId = ""
        $this.ResourceGroupName = ""
        $this.ResourceGroupId = ""
        # Storage Account
        $this.StorageAccountName = ""
        # Azure Search
        $this.AzSearchServiceName = ""
        $this.AzSearchServicEndpoint = ""
        # AKS
        $this.AksName = ""
        $this.AksMid = ""
        # Container Registry
        $this.AzContainerRegistryName = ""
        # Cognitive Service - Azure AI Intelligence Document Service
        $this.AzCognitiveServiceName = ""
        $this.AzCognitiveServiceEndpoint = ""
        # Open AI Service
        $this.AzOpenAiServiceName = ""
        $this.AzOpenAiServiceEndpoint = ""
        # Model - GPT4o
        $this.AzGPT4oModelName = ""
        $this.AzGPT4oModelId = ""
        # Model - Embedding
        $this.AzGPTEmbeddingModelName = ""
        $this.AzGPTEmbeddingModelId = ""
        # Cosmos DB
        $this.AzCosmosDBName = ""
        $this.AzCosmosDBConnectionString = ""
        # App Configuration
        $this.AzAppConfigEndpoint = ""
        # App Config Name
        $this.AzAppConfigName = ""

    }

    [void]MapResultAzd() {

        # Replace direct $envValues lookups with function calls
        $this.TenantId                = Get-AzdEnvValueOrDefault -KeyName "AZURE_TENANT_ID" -Required $true
        $this.SubscriptionId          = Get-AzdEnvValueOrDefault -KeyName "AZURE_SUBSCRIPTION_ID" -Required $true

        # Add your code here
        $this.ResourceGroupName       = Get-AzdEnvValueOrDefault -KeyName "RESOURCE_GROUP_NAME" -Required $true
        $this.ResourceGroupId         = Get-AzdEnvValueOrDefault -KeyName "AZURE_RESOURCE_GROUP_ID" -Required $true

        # Storage Account
        $this.StorageAccountName      = Get-AzdEnvValueOrDefault -KeyName "STORAGE_ACCOUNT_NAME"

        # Azure Search
        $this.AzSearchServiceName     = Get-AzdEnvValueOrDefault -KeyName "AZURE_SEARCH_SERVICE_NAME"
        $this.AzSearchServicEndpoint  = "https://$($this.AzSearchServiceName).search.windows.net"

        # Azure Kubernetes
        $this.AksName                 = Get-AzdEnvValueOrDefault -KeyName "AZURE_AKS_NAME"
        $this.AksMid                  = Get-AzdEnvValueOrDefault -KeyName "AZURE_AKS_MI_ID"

        # Azure Container Registry
        $this.AzContainerRegistryName = Get-AzdEnvValueOrDefault -KeyName "AZURE_CONTAINER_REGISTRY_NAME"

        # Azure Cognitive Service - Azure AI Document Intelligence Service
        $this.AzCognitiveServiceName     = Get-AzdEnvValueOrDefault -KeyName "AZURE_COGNITIVE_SERVICE_NAME"
        $this.AzCognitiveServiceEndpoint = Get-AzdEnvValueOrDefault -KeyName "AZURE_COGNITIVE_SERVICE_ENDPOINT"

        # Azure Open AI Service
        $this.AzOpenAiServiceName     = Get-AzdEnvValueOrDefault -KeyName "AZURE_OPENAI_SERVICE_NAME"
        $this.AzOpenAiServiceEndpoint = Get-AzdEnvValueOrDefault -KeyName "AZURE_OPENAI_SERVICE_ENDPOINT"

        # Azure Cosmos DB
        $this.AzCosmosDBName          = Get-AzdEnvValueOrDefault -KeyName "AZURE_COSMOSDB_NAME"

        # Azure Open AI Service Models
        $this.AzGPT4oModelName        = Get-AzdEnvValueOrDefault -KeyName "AZ_GPT4O_MODEL_NAME"
        $this.AzGPT4oModelId          = Get-AzdEnvValueOrDefault -KeyName "AZ_GPT4O_MODEL_ID"
        $this.AzGPTEmbeddingModelName = Get-AzdEnvValueOrDefault -KeyName "AZ_GPT_EMBEDDING_MODEL_NAME"
        $this.AzGPTEmbeddingModelId   = Get-AzdEnvValueOrDefault -KeyName "AZ_GPT_EMBEDDING_MODEL_ID"

        # Azure App Configuration
        $this.AzAppConfigEndpoint     = Get-AzdEnvValueOrDefault -KeyName "AZURE_APP_CONFIG_ENDPOINT"
        $this.AzAppConfigName         = Get-AzdEnvValueOrDefault -KeyName "AZURE_APP_CONFIG_NAME"
    }

    [void]MapResultAz([string]$resourceGroupName) {
        # Get deployment outputs
        $deploymentName=$(az group show --name "$resourceGroupName" --query "tags.DeploymentName" -o tsv)
        $deploymentOutputs=$(az deployment group show --resource-group "$resourceGroupName" --name "$deploymentName" --query "properties.outputs" -o json | ConvertFrom-Json)

        $this.TenantId                = $deploymentOutputs.azurE_TENANT_ID.value
        if (!$this.TenantId) {
            $this.TenantId = $(az account show --query tenantId -o tsv)
        }

        $this.SubscriptionId          = $(az account show --query id -o tsv)

        # Resource Group
        $this.ResourceGroupName       = $resourceGroupName
        $this.ResourceGroupId         = $deploymentOutputs.azurE_RESOURCE_GROUP_ID.value
        if (!$this.ResourceGroupId) {
            Write-Error "Required value 'AZURE_RESOURCE_GROUP_ID' not found in the deployment outputs."
            exit 1
        }

        # Storage Account
        $this.StorageAccountName      = $deploymentOutputs.storagE_ACCOUNT_NAME.value

        # Search Service
        $this.AzSearchServiceName     = $deploymentOutputs.azurE_SEARCH_SERVICE_NAME.value
        $this.AzSearchServicEndpoint  = "https://$($this.AzSearchServiceName).search.windows.net"

        # AKS
        $this.AksName                 = $deploymentOutputs.azurE_AKS_NAME.value
        $this.AksMid                  = $deploymentOutputs.azurE_AKS_MI_ID.value

        # Container Registry
        $this.AzContainerRegistryName = $deploymentOutputs.azurE_CONTAINER_REGISTRY_NAME.value

        # Cognitive Service - Azure AI Document Intelligence Service
        $this.AzCognitiveServiceName     = $deploymentOutputs.azurE_COGNITIVE_SERVICE_NAME.value
        $this.AzCognitiveServiceEndpoint = $deploymentOutputs.azurE_COGNITIVE_SERVICE_ENDPOINT.value

        # Open AI Service
        $this.AzOpenAiServiceName     = $deploymentOutputs.azurE_OPENAI_SERVICE_NAME.value
        $this.AzOpenAiServiceEndpoint = $deploymentOutputs.azurE_OPENAI_SERVICE_ENDPOINT.value

        # Cosmos DB
        $this.AzCosmosDBName          = $deploymentOutputs.azurE_COSMOSDB_NAME.value

        # Open AI Service Models
        $this.AzGPT4oModelName        = $deploymentOutputs.aZ_GPT4O_MODEL_NAME.value
        $this.AzGPT4oModelId          = $deploymentOutputs.aZ_GPT4O_MODEL_ID.value
        $this.AzGPTEmbeddingModelName = $deploymentOutputs.aZ_GPT_EMBEDDING_MODEL_NAME.value
        $this.AzGPTEmbeddingModelId   = $deploymentOutputs.aZ_GPT_EMBEDDING_MODEL_ID.value

        # App Configuration
        $this.AzAppConfigEndpoint     = $deploymentOutputs.azurE_APP_CONFIG_ENDPOINT.value
        $this.AzAppConfigName         = $deploymentOutputs.azurE_APP_CONFIG_NAME.value

    }
}

function Check-Docker {
    try {
        # Try to get Docker info to check if Docker daemon is running
        $dockerInfo = docker info 2>&1
        if ($LASTEXITCODE -ne 0 -or $dockerInfo -match "error during connect") {
            return $false
        }
        else {
            return $true
        }
    }
    catch {
        Write-Host "An error occurred while checking Docker status." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false    
    }
}

# Check if Docker is running before proceeding
if (-not (Check-Docker)) {
    Write-Host "Docker is not running. Please start Docker and try again." -ForegroundColor Red
    failureBanner
    exit 1
}

###########################################################################
#
# Deployment Main Script
#
###########################################################################

try {
    ###############################################################
    # Step 1 : Deploy Azure resources
    Show-Banner -Title "Step 1 : Deploy Azure resources"
    ###############################################################
    $deploymentResult = [DeploymentResult]::new()
    
    # Deploy Azure Resources
    Write-Host "Retrieving the deployment details.....`r`n" -ForegroundColor Yellow

    # Map the deployment result to DeploymentResult object from .env file
    Write-Host "Mapping the deployment details.....`r`n" -ForegroundColor Yellow
    Write-Host "Resource Group Name: $ResourceGroupName" -ForegroundColor Yellow
    if ($ResourceGroupName) {
        Write-Host "Using provided resource group name: $ResourceGroupName" -ForegroundColor Yellow
        $deploymentResult.MapResultAz($ResourceGroupName.Trim())
    }
    else {
        Write-Host "Using azd environment." -ForegroundColor Yellow
        $deploymentResult.MapResultAzd()
    }

    LoginAzure $deploymentResult.TenantId $deploymentResult.SubscriptionId

    # Display the deployment result
    DisplayResult($deploymentResult)

    # Step 1.2 Validate the deployment result
    # Validate if the Storage Account Name is empty or null    
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.StorageAccountName -variableName "Storage Account Name"

    # Check if ResourceGroupName is valid
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.ResourceGroupName -variableName "Resource group name"  
   
    # Check if AzCosmosDBName is valid
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.AzCosmosDBName -variableName "Az Cosmos DB name"  
    
    # Check if AzCognitiveServiceName is valid
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.AzCognitiveServiceName -variableName "Az Cognitive Service name"  
    
    # Check if AzSearchServiceName is valid
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.AzSearchServiceName -variableName "Az Search Service name"  
    
    # Check if AzOpenAiServiceName is valid
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.AzOpenAiServiceName -variableName "Az OpenAI Service name"  
      
    # Get MongoDB connection string
    $deploymentResult.AzCosmosDBConnectionString = az cosmosdb keys list --name $deploymentResult.AzCosmosDBName --resource-group $deploymentResult.ResourceGroupName --type connection-strings --query "connectionStrings[0].connectionString" -o tsv

    Write-Host "Validation Completed" -ForegroundColor Green

    # Step 1-3 Loading aiservice's configution file template then replace the placeholder with the actual values
    # Define the placeholders and their corresponding values for AI service configuration
    
    $aiServicePlaceholders = @{
        '{gpt-4o-mini-endpoint}' = $deploymentResult.AzOpenAiServiceEndpoint
        '{cosmosmongo-connection-string}' = $deploymentResult.AzCosmosDBConnectionString 
        '{azureblobs-account}' = $deploymentResult.StorageAccountName
        '{azureaisearch-endpoint}' = $deploymentResult.AzSearchServicEndpoint 
        '{gpt-4o-mini-modelname}' = $deploymentResult.AzGPT4oModelId  
        '{gpt-4o-endpoint}' =  $deploymentResult.AzOpenAiServiceEndpoint 
        '{textembedding-endpoint}' = $deploymentResult.AzOpenAiServiceEndpoint
        '{azureopenaiembedding-endpoint}' = $deploymentResult.AzOpenAiServiceEndpoint
        '{azureopenaitext-endpoint}' = $deploymentResult.AzOpenAiServiceEndpoint
        '{azureopenaitext-deployment}' = $deploymentResult.AzGPT4oModelId 
        '{textembedding-modelname}' = $deploymentResult.AzGPTEmbeddingModelName
        '{cosmosmongo-chat-history-collection}' = "ChatHistory"
        '{cosmosmongo-chat-history-database}' = "DPS"
        '{cosmosmongo-document-manager-collection}' = "Documents"
        '{cosmosmongo-document-manager-database}' = "DPS"
        '{azureaidocintel-endpoint}' = $deploymentResult.AzCognitiveServiceEndpoint 
        '{documentintelligence-endpoint}' = $deploymentResult.AzCognitiveServiceEndpoint 
        '{azureblobs-container}' = "smemory"
        '{azurequeues-account}' = $deploymentResult.StorageAccountName
        '{gpt-4o-modelname}' = $deploymentResult.AzGPT4oModelName 
        '{azureopenaiembedding-deployment}' = $deploymentResult.AzGPTEmbeddingModelName 
        '{kernelmemory-endpoint}' = "http://kernelmemory-service" 
    }

    ## Load and update the AI service configuration template
    $aiServiceConfigTemplate = Get-Content -Path .\appconfig\aiservice\appconfig.jsonl -Raw
    $aiServiceConfigTemplate = Invoke-PlaceholdersReplacement $aiServiceConfigTemplate $aiServicePlaceholders

    Write-Host "Update Configuration files Completed." -ForegroundColor Green
    
    ######################################################################################################################
    # Step 2 : Configure Kubernetes Infrastructure
    Show-Banner -Title "Step 2 : Configure Kubernetes Infrastructure"
    ######################################################################################################################
    # 0. Attach Container Registry to AKS
    Write-Host "Attach Container Registry to AKS" -ForegroundColor Green

    $maxRetries = 10
    $retryCount = 0
    $delay = 30 # Delay in seconds

    while ($retryCount -lt $maxRetries) {
        try {
            # Attempt to update the AKS cluster
            az aks update --name $deploymentResult.AksName --resource-group $deploymentResult.ResourceGroupName --attach-acr $deploymentResult.AzContainerRegistryName
            Write-Host "AKS cluster updated successfully."
            break
        } catch {
            $errorMessage = $_.Exception.Message
            if ($errorMessage -match "OperationNotAllowed" -and $errorMessage -match "Another operation \(Updating\) is in progress") {
                Write-Host "Operation not allowed: Another operation is in progress. Retrying in $delay seconds..."
                Start-Sleep -Seconds $delay
                $retryCount++
            } else {
                Write-Host "An unexpected error occurred: $errorMessage" -ForegroundColor Red
                throw $_
            }
        }
    }

    if ($retryCount -eq $maxRetries) {
        Write-Host "Max retries reached. Failed to update the AKS cluster." -ForegroundColor Red
        failureBanner
        exit 1
    }
    
    #az aks update --name $deploymentResult.AksName --resource-group $deploymentResult.ResourceGroupName --attach-acr $deploymentResult.AzContainerRegistryName
    $kubenamespace = "ns-km"

    # 1. Get the Kubernetes resource group
    try {
        Write-Host "Getting the Kubernetes resource group..." -ForegroundColor Cyan
        $aksResourceGroupName = $(az aks show --resource-group $deploymentResult.ResourceGroupName --name $deploymentResult.AksName --query nodeResourceGroup --output tsv)
        Write-Host "Kubernetes resource group: $aksResourceGroupName" -ForegroundColor Green
        Write-Output "krg_name=$aksResourceGroupName" >> $Env:GITHUB_ENV
        
    }
    catch {
        Write-Host "Failed to get the Kubernetes resource group." -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.Exception.StackTrace -ForegroundColor Red
        failureBanner
        exit 1
    }

    # 2.Connect to AKS cluster
    try {
        Write-Host "Connecting to AKS cluster..." -ForegroundColor Cyan
        az aks get-credentials --resource-group $deploymentResult.ResourceGroupName --name $deploymentResult.AksName --overwrite-existing
        Write-Host "Connected to AKS cluster." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to connect to AKS cluster." -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.Exception.StackTrace -ForegroundColor Red
        failureBanner
        exit 1
    }
    
    # 3.Create namespace for AI Service
    kubectl create namespace $kubenamespace
    
    Write-Host "Enable Add routing addon for AKS" -ForegroundColor Yellow
    
    # 4.approuting enable and enable addons for http_application_routing
    try {
        Write-Host "Enabling application routing addon for AKS..." -ForegroundColor Cyan
        Import-Module .\kubernetes\enable_approuting.psm1
        Enable-AppRouting -ResourceGroupName $deploymentResult.ResourceGroupName -ClusterName $deploymentResult.AksName
        Write-Host "Application routing addon enabled." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to enable application routing addon." -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.Exception.StackTrace -ForegroundColor Red
        failureBanner
        exit 1
    }
    
    # 5. Get the public IP address for the default public ingress controller
    #    https://learn.microsoft.com/en-us/azure/aks/app-routing

    $appRoutingNamespace = "app-routing-system"
    while ($true) {
        $externalIP = Get-ExternalIP -serviceName 'nginx' -namespace $appRoutingNamespace
        if ($externalIP -and $externalIP -ne "<none>") {
            Write-Host "Get EXTERNAL-IP for nginx in $appRoutingNamespace namespace is: $externalIP"
            break
        } else {
            Write-Host "Waiting for EXTERNAL-IP to be assigned..."
            Start-Sleep -Seconds 10
        }
    }

    # 6. Assign DNS Name to the public IP address
    #  6-1. Get Az Network resource Name with the public IP address
    Write-Host "Assign DNS Name to the public IP address" -ForegroundColor Green
    $publicIpName=$(az network public-ip list --resource-group $aksResourceGroupName --query "[?ipAddress=='$externalIP'].name" --output tsv)
    #  6-2. Generate Unique backend API fqdn Name - esgdocanalysis-3 digit random number with padding 0
    $dnsName = "kmgs$($(Get-Random -Minimum 0 -Maximum 9999).ToString("D4"))"
    
    # Validate if the AKS Resource Group Name, Public IP name and DNS Name are provided
    ValidateVariableIsNullOrEmpty -variableValue $aksResourceGroupName -variableName "AKS Resource Group name"  
    
    ValidateVariableIsNullOrEmpty -variableValue $publicIpName -variableName "Public IP name" 

    ValidateVariableIsNullOrEmpty -variableValue $dnsName -variableName "DNS Name" 
    
    #  6-3. Assign DNS Name to the public IP address
    az network public-ip update --resource-group $aksResourceGroupName --name $publicIpName --dns-name $dnsName

    #  6-4. Get FQDN for the public IP address
    $fqdn = az network public-ip show --resource-group $aksResourceGroupName --name $publicIpName --query "dnsSettings.fqdn" --output tsv
     
    # Validate if the FQDN is null or empty
    ValidateVariableIsNullOrEmpty -variableValue $fqdn -variableName "FQDN"    

    # Ensure that the required fields are not null or empty
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.ResourceGroupName -variableName "Resource group name"    
    
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.AksName -variableName "AKS cluster name"    
    
    # Get vmss resource group name
    $vmssResourceGroupName = $(az aks show --resource-group $deploymentResult.ResourceGroupName --name $deploymentResult.AksName --query nodeResourceGroup --output tsv)
    
    # Validate if vmss Resource Group Name is null or empty
    ValidateVariableIsNullOrEmpty -variableValue $vmssResourceGroupName -variableName "VMSS resource group"    
        
    # Get vmss name
    $vmssName = $(az vmss list --resource-group $vmssResourceGroupName --query "[0].name" --output tsv)
    
    # Validate if vmss Name is null or empty
    ValidateVariableIsNullOrEmpty -variableValue $vmssName -variableName "VMSS name"    
        
    # Create System Assigned Managed Identity
    $systemAssignedIdentity = $(az vmss identity assign --resource-group $vmssResourceGroupName --name $vmssName --query systemAssignedIdentity --output tsv)

    # Validate if System Assigned Identity is null or empty
    ValidateVariableIsNullOrEmpty -variableValue $systemAssignedIdentity -variableName "System-assigned managed identity"    
    
    # Validate if ResourceGroupId is null or empty
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.ResourceGroupId -variableName "ResourceGroupId"    
 
    # Assign the role for aks system assigned managed identity to App Configuration Data Reader role with the scope of Resourcegroup
    Write-Host "Assign the role for aks system assigned managed identity to App Configuration Data Reader role" -ForegroundColor Green
    az role assignment create --assignee $systemAssignedIdentity --role "App Configuration Data Reader" --scope $deploymentResult.ResourceGroupId
    
    # Assign the role for aks system assigned managed identity to Azure blob storage Data Contributor role with the scope of Storage Account
    Write-Host "Assign the role for aks system assigned managed identity to App Storage Blob Data Contributor role" -ForegroundColor Green
    az role assignment create --assignee $systemAssignedIdentity --role "Storage Blob Data Contributor" --scope "/subscriptions/$($deploymentResult.SubscriptionId)/resourceGroups/$($deploymentResult.ResourceGroupName)/providers/Microsoft.Storage/storageAccounts/$($deploymentResult.StorageAccountName)"

    # Assign the role for aks system assigned managed identity to Azure Queue Data Contributor role with the scope of Storage Account
    Write-Host "Assign the role for aks system assigned managed identity to App Storage Queue Data Contributor role" -ForegroundColor Green
    az role assignment create --assignee $systemAssignedIdentity --role "Storage Queue Data Contributor" --scope "/subscriptions/$($deploymentResult.SubscriptionId)/resourceGroups/$($deploymentResult.ResourceGroupName)/providers/Microsoft.Storage/storageAccounts/$($deploymentResult.StorageAccountName)"

    # Assign the role for aks system assigned managed identity to Azure Queue Data Contributor role with the scope of Storage Account
    Write-Host "Assign the role for aks system assigned managed identity to App Cognitive Services OpenAI User role" -ForegroundColor Green
    az role assignment create --assignee $systemAssignedIdentity --role "Cognitive Services OpenAI User" --scope "/subscriptions/$($deploymentResult.SubscriptionId)/resourceGroups/$($deploymentResult.ResourceGroupName)/providers/Microsoft.CognitiveServices/accounts/$($deploymentResult.AzOpenAiServiceName)"

    # Assign the role for aks system assigned managed identity to Azure Queue Data Contributor role with the scope of Storage Account
    Write-Host "Assign the role for aks system assigned managed identity to App Search Index Data Contributor role" -ForegroundColor Green
    az role assignment create --assignee $systemAssignedIdentity --role "Search Index Data Contributor" --scope "/subscriptions/$($deploymentResult.SubscriptionId)/resourceGroups/$($deploymentResult.ResourceGroupName)/providers/Microsoft.Search/searchServices/$($deploymentResult.AzSearchServiceName)"

    # Assign the role for aks system assigned managed identity to Azure Queue Data Contributor role with the scope of Storage Account
    Write-Host "Assign the role for aks system assigned managed identity to App Search Service Contributor role" -ForegroundColor Green
    az role assignment create --assignee $systemAssignedIdentity --role "Search Service Contributor" --scope "/subscriptions/$($deploymentResult.SubscriptionId)/resourceGroups/$($deploymentResult.ResourceGroupName)/providers/Microsoft.Search/searchServices/$($deploymentResult.AzSearchServiceName)"

    # Assign the role for aks system assigned managed identity to Azure Queue Data Contributor role with the scope of Storage Account
    Write-Host "Assign the role for aks system assigned managed identity to App Cognitive Services User role" -ForegroundColor Green
    az role assignment create --assignee $systemAssignedIdentity --role "Cognitive Services User" --scope "/subscriptions/$($deploymentResult.SubscriptionId)/resourceGroups/$($deploymentResult.ResourceGroupName)/providers/Microsoft.CognitiveServices/accounts/$($deploymentResult.AzCognitiveServiceName)"

    # 8. Update aks nodepools to updated new role
    try {
        Write-Host "Upgrading node pools..." -ForegroundColor Cyan
        $nodePools = $(az aks nodepool list --resource-group $deploymentResult.ResourceGroupName --cluster-name $deploymentResult.AksName --query [].name --output tsv)
        foreach ($nodePool in $nodePools) {
            Write-Host "Upgrading node pool: $nodePool" -ForegroundColor Cyan
            Write-Host "Node pool $nodePool upgrade initiated." -ForegroundColor Green
            az aks nodepool upgrade --resource-group $deploymentResult.ResourceGroupName --cluster-name $deploymentResult.AksName --name $nodePool 
        }
    }
    catch {
        Write-Host "Failed to upgrade node pools." -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.Exception.StackTrace -ForegroundColor Red
        failureBanner
        exit 1
    }

    #########################################################################################################################################
    # Step 3 : Update Kubernetes configuration files with the FQDN, Container Image Path and Email address for the certificate management
    #Write-Host "Step 3 : Update Kubernetes yaml files with Container Image Path and Email address for the certificate management" -ForegroundColor Yellow
    Show-Banner -Title "Step 3 : Update Kubernetes yaml files with Container Image Path and Email address for the certificate management"
    #########################################################################################################################################

    # 3.1 Update deploy.certclusterissuer.yaml.template file and save as deploy.certclusterissuer.yaml
    $certManagerTemplate = Get-Content -Path .\kubernetes\deploy.certclusterissuer.yaml.template -Raw
    $certManagerTemplate = $certManagerTemplate -replace '{{ your-email }}', $email
    $certManagerPath = ".\kubernetes\deploy.certclusterissuer.yaml"
    $certManagerTemplate | Set-Content -Path $certManagerPath -Force

    # 3.2 Update deploy.ingress.yaml.template file and save as deploy.ingress.yaml
    # webfront / apibackend
    $ingressPlaceholders = @{
        '{{ fqdn }}' = $fqdn
    }

    $ingressTemplate = Get-Content -Path .\kubernetes\deploy.ingress.yaml.template -Raw
    $ingress = Invoke-PlaceholdersReplacement $ingressTemplate $ingressPlaceholders
    $ingressPath = ".\kubernetes\deploy.ingress.yaml"
    $ingress | Set-Content -Path $ingressPath -Force
    Write-Host "Ingress Controller configuration file have been updated successfully." -ForegroundColor Green


    # 3.3 Update deploy.deployment.yaml.template file and save as deploy.deployment.yaml
    # Validate AzContainerRegistryName IsNull Or Empty.
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.AzContainerRegistryName -variableName "Azure Container Registry Name"

    ## Define Image Tags
    $acrNamespace = "kmgs"
    $acrAIServiceTag = "$($deploymentResult.AzContainerRegistryName).azurecr.io/$acrNamespace/aiservice"
    $acrKernelMemoryTag = "$($deploymentResult.AzContainerRegistryName).azurecr.io/$acrNamespace/kernelmemory"
    $acrFrontAppTag = "$($deploymentResult.AzContainerRegistryName).azurecr.io/$acrNamespace/frontapp"
    
    # Validate AI Service Tag IsNull Or Empty.    
    ValidateVariableIsNullOrEmpty -variableValue $acrAIServiceTag -variableName "AI Service Tag"
    # Validate Kernel Memory Tag IsNull Or Empty.   
    ValidateVariableIsNullOrEmpty -variableValue $acrKernelMemoryTag -variableName "Kernel Memory Tag"
    # Validate Front App Tag IsNull Or Empty.   
    ValidateVariableIsNullOrEmpty -variableValue $acrFrontAppTag -variableName "Front App Tag"

    $deploymentTemplatePlaceholders = @{
        '{{ aiservice-imagepath }}' = $acrAIServiceTag
        '{{ kernelmemory-imagepath }}' = $acrKernelMemoryTag
        '{{ frontapp-imagepath }}' = $acrFrontAppTag
    }

    $deploymentTemplate = Get-Content -Path .\kubernetes\deploy.deployment.yaml.template -Raw
    $deployment = Invoke-PlaceholdersReplacement $deploymentTemplate $deploymentTemplatePlaceholders
    $deploymentPath = ".\kubernetes\deploy.deployment.yaml"
    $deployment | Set-Content -Path $deploymentPath -Force

    ########################################################################################################################################################
    # Step 4 : Configure AKS (deploy Cert Manager, Ingress Controller) and Deploy Images on the kubernetes cluster
    #Write-Host "Step 4 : Configure AKS (deploy Cert Manager) and Deploy Images on the kubernetes cluster" -ForegroundColor Yellow
    Show-Banner -Title "Step 4 : Configure AKS (deploy Cert Manager) and Deploy Images on the kubernetes cluster"
    ########################################################################################################################################################
    function Wait-ForCertManager {
        Write-Host "Waiting for Cert-Manager to be ready..." -ForegroundColor Cyan
        while ($true) {
            $certManagerPods = kubectl get pods -n cert-manager -l app.kubernetes.io/instance=cert-manager -o jsonpath='{.items[*].status.phase}'
            if ($certManagerPods -eq "Running Running Running") {
                Write-Host "Cert-Manager is running." -ForegroundColor Green
                break
            } else {
                Write-Host "Cert-Manager is not ready yet. Waiting..." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
            }
        }
    }
    
    Write-Host "Deploying Cert Manager" -ForegroundColor Green
    # 4.1. Install Cert Manager and nginx ingress controller in Kubernetes for SSL/TLS certificate
    # Install Cert-Manager
    Write-Host "Deploying...." -ForegroundColor Green
    helm repo add jetstack https://charts.jetstack.io --force-update
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
    
    # Wait for Cert-Manager to be ready
    Wait-ForCertManager


    #======================================================================================================================================================================
    # Validate AzAppConfigEndpoint IsNull Or Empty.
    ValidateVariableIsNullOrEmpty -variableValue $deploymentResult.AzAppConfigEndpoint -variableName "Azure App Configuration Endpoint"
    # App Deployment after finishing the AKS infrastructure setup
    $appConfigServicePlaceholders = @{
        '{{ appconfig-url }}' = $deploymentResult.AzAppConfigEndpoint
    }

    ##############################
    # Kernel Memory Service
    ##############################
    ## Load and update the kernel memory service configuration template
    $kernelMemoryServiceConfigTemplate = Get-Content -Path .\appconfig\kernelmemory\appsettings.Development.json.template -Raw
    $kernelMemoryServiceConfigTemplate = Invoke-PlaceholdersReplacement $kernelMemoryServiceConfigTemplate $appConfigServicePlaceholders

    ## Save the updated kernel memory service configuration file
    $kernelMemoryServiceConfigPath = ".\appconfig\kernelmemory\appsettings.Development.json"
    $kernelMemoryServiceConfigTemplate | Set-Content -Path $kernelMemoryServiceConfigPath -Force
    Write-Host "Kernel Memory Service Application Configuration file has been updated successfully." -ForegroundColor Green
        
    ###############################
    # AI service
    ###############################
    ## Load and update the ai service configuration template
    $aiServiceConfigTemplate = Get-Content -Path .\appconfig\aiservice\appsettings.Development.json.template -Raw
    $aiServiceConfigTemplate = Invoke-PlaceholdersReplacement $aiServiceConfigTemplate $appConfigServicePlaceholders

    ## Save the updated kernel memory service configuration file
    $aiServiceConfigPath = ".\appconfig\aiservice\appsettings.Development.json"
    $aiServiceConfigTemplate | Set-Content -Path $aiServiceConfigPath -Force
    Write-Host "AI Service Application Configuration file has been updated successfully." -ForegroundColor Green

    ###############################
    # Front App
    ###############################
    
    $frontAppConfigServicePlaceholders = @{
        '{{ backend-fqdn }}' = "https://${fqdn}/backend"
    }
    
    ## Load and update the front app configuration template
    $frontAppConfigTemplate = Get-Content -Path .\appconfig\frontapp\.env.template -Raw
    $frontAppConfigTemplate = Invoke-PlaceholdersReplacement $frontAppConfigTemplate $frontAppConfigServicePlaceholders

    ## Save the updated front app configuration file
    $frontAppConfigPath = ".\appconfig\frontapp\.env"
    $frontAppConfigTemplate | Set-Content -Path $frontAppConfigPath -Force
    Write-Host "Front App Application Configuration file has been updated successfully." -ForegroundColor Green

    # Step 3-3 Copy the configuration files to the source folders
    ## Copy two configuration files to each source folder
    Write-Host "Copying the configuration files to the source folders" -ForegroundColor Green
    Copy-Item -Path $aiServiceConfigPath -Destination "..\App\backend-api\Microsoft.GS.DPS.Host\appsettings.Development.json" -Force
    Copy-Item -Path $kernelMemoryServiceConfigPath -Destination "..\App\kernel-memory\service\Service\appsettings.Development.json" -Force
    Copy-Item -Path $frontAppConfigPath -Destination "..\App\frontend-app\.env" -Force

    ######################################################################################################################
    # Step 5 : docker build and push container images to Azure Container Registry
    Show-Banner -Title "Step 5 : docker build and push container images to Azure Container Registry"
    ######################################################################################################################
    # $acrNamespace = "kmgs"
    # $acrAIServiceTag = "$($deploymentResult.AzContainerRegistryName).azurecr.io/$acrNamespace/aiservice"
    # $acrKernelMemoryTag = "$($deploymentResult.AzContainerRegistryName).azurecr.io/$acrNamespace/kernelmemory"
    # $acrFrontAppTag = "$($deploymentResult.AzContainerRegistryName).azurecr.io/$acrNamespace/frontapp"

    # 1. Login to Azure Container Registry
    az acr login --name $deploymentResult.AzContainerRegistryName
    
    # $acrNamespace = "kmgs"
    # 2. Build and push the images to Azure Container Registry
    #  2-1. Build and push the AI Service container image to  Azure Container Registry
    #$acrAIServiceTag = "$($deploymentResult.AzContainerRegistryName).azurecr.io/$acrNamespace/aiservice"
    docker build "../App/backend-api/." --no-cache -t $acrAIServiceTag
    docker push $acrAIServiceTag

    #  2-2. Build and push the Kernel Memory Service container image to Azure Container Registry
    #$acrKernelMemoryTag = "$($deploymentResult.AzContainerRegistryName).azurecr.io/$acrNamespace/kernelmemory"
    docker build "../App/kernel-memory/." --no-cache -t $acrKernelMemoryTag
    docker push $acrKernelMemoryTag

    #  2-3. Build and push the Frontend App Service container image to Azure Container Registry
    #$acrFrontAppTag = "$($deploymentResult.AzContainerRegistryName).azurecr.io/$acrNamespace/frontapp"
    docker build "../App/frontend-app/." --no-cache -t $acrFrontAppTag
    docker push $acrFrontAppTag

    #======================================================================================================================================================================

    # 5.2. Deploy ClusterIssuer in Kubernetes for SSL/TLS certificate
    kubectl apply -f "./kubernetes/deploy.certclusterissuer.yaml"

    # 5.3. Deploy Deployment in Kubernetes
    kubectl apply -f "./kubernetes/deploy.deployment.yaml" -n $kubenamespace

    # 5.4. Deploy Services in Kubernetes
    kubectl apply -f "./kubernetes/deploy.service.yaml" -n $kubenamespace

    # 5.5. Deploy Ingress Controller in Kubernetes for external access
    kubectl apply -f "./kubernetes/deploy.ingress.yaml" -n $kubenamespace

    # #####################################################################
    # # Data file uploading
    # Show-Banner -Title "Step 9 : Sample Data Uploading to the Backend API - https://${fqdn}/backend/Documents/ImportDocument"
    # #####################################################################
    # Import-Module .\send-filestoendpoint.psm1
    # Send-FilesToEndpoint -DataFolderPath "..\Data" -EndpointUrl "https://${fqdn}/backend/Documents/ImportDocument"


    #####################################################################
    # Step 6 : Display the deployment result and following instructions
    #####################################################################
    #Write-Host "Deployment has been completed successfully." -ForegroundColor Green
    successBanner

    $messageString = "Please find the deployment details below: `r`n" +
    "1. Check Front Web Application with this URL - https://${fqdn} `n`r" +
    "2. Check GPT Model's TPM rate in your resource group - $($deploymentResult.ResourceGroupName) `n`r" +
    "Please set each value high as much as you can set`n`r" +
    "`t- Open AI Resource Name - $($deploymentResult.AzOpenAiServiceName) `n`r" +
    "`t- GPT Model - $($deploymentResult.AzGPT4oModelName) `n`r" +
    "`t- GPT Embedding Model - $($deploymentResult.AzGPTEmbeddingModelName) `n`r"
    Write-Host $messageString -ForegroundColor Yellow
    Write-Host "Don't forget to control the TPM rate for your GPT and Embedding Model in Azure Open AI Studio Deployments section." -ForegroundColor Red
    Write-Host "After controlling the TPM rate for your GPT and Embedding Model, let's start Data file import process with this command." -ForegroundColor Yellow
    Write-Host ".\uploadfiles.ps1 -EndpointUrl https://${fqdn}" -ForegroundColor Green
}
catch {
    Write-Host "An error occurred during deployment." -ForegroundColor Red
    Write-Host "Error details:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
}