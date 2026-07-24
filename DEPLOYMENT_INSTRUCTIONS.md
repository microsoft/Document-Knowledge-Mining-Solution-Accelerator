# Deployment Guide: GPT-5 Streaming Fix

## Quick Start (Choose One Option)

### Option 1: Automated Deployment (Recommended)
```bash
chmod +x deploy-km-fix.sh check-km-logs.sh
./deploy-km-fix.sh
```

### Option 2: Manual Step-by-Step

#### Step 1: Navigate to KernelMemory directory
```bash
cd App/kernel-memory
```

#### Step 2: Build Docker image
```bash
# Replace these with your actual values:
export ACR_URL="your-registry.azurecr.io"  # e.g., dpskmgs9173.azurecr.io
export IMAGE_TAG="gpt5-fix"

docker build -t ${ACR_URL}/kernel-memory:${IMAGE_TAG} -f Dockerfile .
```

#### Step 3: Push to Azure Container Registry
```bash
# Login if needed
az acr login --name <registry-name>

# Push image
docker push ${ACR_URL}/kernel-memory:${IMAGE_TAG}
```

#### Step 4: Update Container App
```bash
# Replace with your values:
export ACR_URL="your-registry.azurecr.io"
export RG_NAME="rg-pridkmma84"
export KM_APP_NAME="kernel-memory-service"
export IMAGE_TAG="gpt5-fix"

az containerapp update \
  --name ${KM_APP_NAME} \
  --resource-group ${RG_NAME} \
  --image ${ACR_URL}/kernel-memory:${IMAGE_TAG}
```

#### Step 5: Verify deployment
```bash
# Check status
az containerapp show \
  --name ${KM_APP_NAME} \
  --resource-group ${RG_NAME} \
  --query "properties.provisioningState" -o tsv

# Should output: "Succeeded"
```

---

## Finding Your Azure Values

### To find your Container Registry URL:
```bash
az acr list --resource-group <rg-name> --query "[].loginServer" -o table
# Output example: dpskmgs9173.azurecr.io
```

### To find your Container App name:
```bash
az containerapp list --resource-group <rg-name> --query "[].name" -o table
# Look for "kernel-memory-*" or "kernelmemory-*"
```

### To find your Resource Group:
```bash
# If you know the name (e.g., rg-pridkmma84):
az group show --name rg-pridkmma84 --query "name" -o tsv

# Or list all:
az group list --query "[].name" -o table
```

---

## Verify Fix After Deployment

### 1. Check logs for errors
```bash
bash check-km-logs.sh
```

### 2. Test the /ask endpoint
```bash
curl -X POST "https://<your-km-url>/ask" \
  -H "Content-Type: application/json" \
  -d '{
    "question": "Hello, can you hear me?",
    "index": "default"
  }'

# Should return: 200 OK (not 500 error)
```

### 3. Full flow test
- Visit your frontend: https://kmgs9173.australiaeast.cloudapp.azure.com
- Upload a test document
- Ask a question about it
- Should work without 500 errors ✅

---

## Troubleshooting

### If you still see 500 error:

**1. Check deployment succeeded**
```bash
az containerapp show --name <km-app> --resource-group <rg> \
  --query "properties.provisioningState" -o tsv
```
Should output: `Succeeded`

**2. Check container is running**
```bash
az containerapp revision list --name <km-app> --resource-group <rg> \
  --query "[0].properties.runningStatus" -o tsv
```
Should output: `Running`

**3. Get detailed logs**
```bash
bash check-km-logs.sh

# Or manually:
az containerapp logs show --name <km-app> --resource-group <rg> --tail 500
```

**4. Restart the container**
```bash
az containerapp revision deactivate \
  --name <km-app> \
  --resource-group <rg> \
  --revision <revision-name>
```

### If deployment fails:

**Build locally first**
```bash
cd App/kernel-memory
dotnet build service/Service/Service.csproj -c Release
```

If build fails, the project has errors that need to be fixed.

---

## What Changed

The fix enables GPT-5 models to work properly:
- ❌ Before: Used streaming API → 500 error with GPT-5
- ✅ After: Uses non-streaming API for GPT-5 only

**Files modified:**
- `App/kernel-memory/extensions/AzureOpenAI/AzureOpenAITextGenerator.cs`

---

## Time Estimates

- Build: ~5-10 minutes
- Push to ACR: ~2-5 minutes  
- Update Container App: ~2-5 minutes
- **Total: ~15-20 minutes**

---

## Rollback (if needed)

To revert to previous version:
```bash
# Use the old image tag
az containerapp update \
  --name <km-app> \
  --resource-group <rg> \
  --image <acr-url>/kernel-memory:previous-tag
```

