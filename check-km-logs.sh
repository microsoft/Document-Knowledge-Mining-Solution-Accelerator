#!/bin/bash

# Get KernelMemory service error logs
echo "=== Checking KernelMemory Service Logs ==="
echo ""
echo "Enter your Azure details:"
read -p "Resource Group Name (e.g., rg-pridkmma84): " rg_name
read -p "KernelMemory Container App Name (e.g., kernelmemory-service): " km_app_name

echo ""
echo "Fetching logs from the last 30 minutes..."
echo "=========================================="
echo ""

# Get logs - look for errors
az containerapp logs show \
  --name "$km_app_name" \
  --resource-group "$rg_name" \
  --tail 200 \
  --format text | grep -i "error\|exception\|streaming\|gpt-5\|500" || echo "No errors found in logs"

echo ""
echo "=========================================="
echo ""
echo "Full recent logs:"
az containerapp logs show \
  --name "$km_app_name" \
  --resource-group "$rg_name" \
  --tail 50 \
  --format text

echo ""
echo "To see all logs, run:"
echo "az containerapp logs show --name $km_app_name --resource-group $rg_name --tail 1000 | tee km_logs.txt"
