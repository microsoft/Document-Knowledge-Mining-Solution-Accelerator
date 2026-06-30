# List of Azure regions to check for quota (update as needed)
$AZURE_REGIONS = "$env:AZURE_REGIONS"
# Ensure regions are correctly split and trimmed
$REGIONS = ($AZURE_REGIONS -split '[,\s]') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

Write-Output "📍 Processed Regions: $($REGIONS -join ', ')"

$SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID
$GPT_MIN_CAPACITY = $env:GPT_MIN_CAPACITY
$TEXT_EMBEDDING_MIN_CAPACITY = $env:TEXT_EMBEDDING_MIN_CAPACITY
# Ensure Azure PowerShell module is installed and imported
Install-Module -Name Az -AllowClobber -Force -Scope CurrentUser
Import-Module Az

# Verify existing Azure session (authentication is handled by the caller workflow via OIDC)
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "❌ Error: No active Azure session found. Ensure the caller workflow authenticates via azure/login@v2 with enable-AzPSSession: true."
        exit 1
    }
    Write-Host "✅ Using existing Azure session: $($context.Account.Id)"
} catch {
    Write-Host "❌ Error: Failed to verify Azure session. $_"
    exit 1
}

Write-Host "🔄 Validating required environment variables..."
if (-not $SUBSCRIPTION_ID -or -not $GPT_MIN_CAPACITY -or -not $TEXT_EMBEDDING_MIN_CAPACITY) {
    Write-Host "❌ ERROR: Missing required environment variables."
    exit 1
}

Write-Host "🔄 Setting Azure subscription..."
$setSubscriptionResult = Set-AzContext -SubscriptionId $SUBSCRIPTION_ID
if ($setSubscriptionResult -eq $null) {
    Write-Host "❌ ERROR: Invalid subscription ID or insufficient permissions."
    exit 1
}
Write-Host "✅ Azure subscription set successfully."

# Define models and their minimum required capacities
$MIN_CAPACITY = @{
    "OpenAI.GlobalStandard.gpt4.1-mini" = $GPT_MIN_CAPACITY
    "OpenAI.GlobalStandard.text-embedding-3-large" = $TEXT_EMBEDDING_MIN_CAPACITY
}

$VALID_REGION = ""

foreach ($REGION in $REGIONS) {
    Write-Host "----------------------------------------"
    Write-Host "🔍 Checking region: $REGION"

    # Get the Cognitive Services usage information for the region
    $QUOTA_INFO = Get-AzCognitiveServicesUsage -Location $REGION
    if (-not $QUOTA_INFO) {
        Write-Host "⚠️ WARNING: Failed to retrieve quota for region $REGION. Skipping."
        continue
    }

    $INSUFFICIENT_QUOTA = $false

    foreach ($MODEL in $MIN_CAPACITY.Keys) {

        $MODEL_INFO = $QUOTA_INFO | Where-Object { $_.Name.Value -eq $MODEL }  
        
        if (-not $MODEL_INFO) {
            Write-Host "⚠️ WARNING: No quota information found for model: $MODEL in $REGION. Skipping."
            $INSUFFICIENT_QUOTA = $true
            break
        }

        $CURRENT_VALUE = [int]$MODEL_INFO.CurrentValue
        $LIMIT = [int]$MODEL_INFO.Limit

        $AVAILABLE = $LIMIT - $CURRENT_VALUE

        Write-Host "✅ Model: $MODEL | Used: $CURRENT_VALUE | Limit: $LIMIT | Available: $AVAILABLE"

        if ($AVAILABLE -lt $MIN_CAPACITY[$MODEL]) {
            Write-Host "❌ ERROR: $MODEL in $REGION has insufficient quota."
            $INSUFFICIENT_QUOTA = $true
            break
        }
    }

    if ($INSUFFICIENT_QUOTA -eq $false) {
        $VALID_REGION = $REGION
        break
    }

}

if (-not $VALID_REGION) {
    Write-Host "❌ No region with sufficient quota found. Blocking deployment."
    echo "QUOTA_FAILED=true" >> $env:GITHUB_ENV  # Set QUOTA_FAILED for subsequent steps
    exit 0
} else {
    Write-Host "✅ Suggested Region: $VALID_REGION"
    echo "VALID_REGION=$VALID_REGION" >> $env:GITHUB_ENV   # Set VALID_REGION for subsequent steps
    exit 0
}
