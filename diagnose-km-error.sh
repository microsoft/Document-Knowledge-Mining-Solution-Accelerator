#!/bin/bash

# KernelMemory Error Diagnostic Script
# This script helps identify the root cause of KernelMemory 500 errors

echo "=== KernelMemory Service Diagnostic ==="
echo ""

# Get deployment info from context
read -p "Enter Azure Container App Name for KernelMemory: " km_app_name
read -p "Enter Resource Group Name: " rg_name
read -p "Enter App Configuration Name: " appconfig_name

echo ""
echo "1. Checking KernelMemory Container Logs..."
echo "=================================================="

# Get recent logs (last 50 lines)
az containerapp logs show \
  --name "$km_app_name" \
  --resource-group "$rg_name" \
  --tail 50 \
  --format text

echo ""
echo "2. Checking Critical Configuration Values..."
echo "=================================================="

# Check Azure AI Search
echo "🔍 Azure AI Search Configuration:"
az appconfig kv show --name "$appconfig_name" \
  --key "Application:Services:AzureAISearch:Endpoint" \
  --query "value" -o tsv 2>/dev/null || echo "❌ NOT FOUND"

# Check Azure OpenAI Embedding
echo "🔍 Azure OpenAI Embedding Configuration:"
az appconfig kv show --name "$appconfig_name" \
  --key "Application:Services:AzureOpenAIEmbedding:Endpoint" \
  --query "value" -o tsv 2>/dev/null || echo "❌ NOT FOUND"

# Check Azure OpenAI Text
echo "🔍 Azure OpenAI Text (GPT) Configuration:"
az appconfig kv show --name "$appconfig_name" \
  --key "Application:Services:AzureOpenAIText:Endpoint" \
  --query "value" -o tsv 2>/dev/null || echo "❌ NOT FOUND"

echo ""
echo "3. Recommended Actions:"
echo "=================================================="
echo "• Check the logs above for specific error messages"
echo "• Verify all endpoints are reachable from Container Apps"
echo "• Check API keys are not expired"
echo "• Verify quota/rate limits in Azure services"
echo "• Check network connectivity (NSG rules, firewall)"
echo ""
