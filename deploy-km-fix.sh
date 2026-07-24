#!/bin/bash
set -e

echo "=== KernelMemory Service - Rebuild & Deploy ==="
echo ""

# Get deployment info
read -p "Azure Container Registry (e.g., <name>.azurecr.io): " acr_url
read -p "Resource Group Name: " rg_name
read -p "KernelMemory Container App Name: " km_app_name
read -p "Container image name (default: kernel-memory): " -i "kernel-memory" image_name

echo ""
echo "Step 1: Building Docker image..."
echo "=================================="

# Build KernelMemory service Docker image
cd "$(dirname "$0")/App/kernel-memory"

docker build -t "${acr_url}/${image_name}:gpt5-fix" \
  -f Dockerfile .

if [ $? -ne 0 ]; then
    echo "❌ Docker build failed!"
    exit 1
fi

echo "✅ Docker image built successfully"
echo ""

echo "Step 2: Pushing to Azure Container Registry..."
echo "=============================================="

docker push "${acr_url}/${image_name}:gpt5-fix"

if [ $? -ne 0 ]; then
    echo "❌ Push to ACR failed!"
    exit 1
fi

echo "✅ Image pushed to ACR"
echo ""

echo "Step 3: Updating Container App..."
echo "=================================="

az containerapp update \
  --name "$km_app_name" \
  --resource-group "$rg_name" \
  --image "${acr_url}/${image_name}:gpt5-fix"

if [ $? -eq 0 ]; then
    echo "✅ Container App updated successfully!"
    echo ""
    echo "Waiting for deployment to complete (30 seconds)..."
    sleep 30
    
    echo ""
    echo "Step 4: Verifying deployment..."
    echo "================================"
    
    # Check if service is running
    az containerapp show \
      --name "$km_app_name" \
      --resource-group "$rg_name" \
      --query "properties.provisioningState" -o tsv
    
    echo ""
    echo "✅ Deployment complete!"
    echo ""
    echo "To test the fix:"
    echo "  - Visit: https://<your-frontend-url>"
    echo "  - Upload a document"
    echo "  - Try asking a question"
    echo ""
    echo "If you still see errors, check logs with:"
    echo "  bash check-km-logs.sh"
else
    echo "❌ Container App update failed!"
    exit 1
fi
