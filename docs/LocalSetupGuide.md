# Local Setup Guide

This guide provides comprehensive instructions for setting up the Document Knowledge Mining Solution Accelerator for local development across Windows, Linux, and macOS platforms.

---
## Step 1: Install Required Tools
Install these tools before you start:
- [Visual Studio](https://visualstudio.microsoft.com/)
- [Visual Studio Code](https://code.visualstudio.com/)

### Windows Development
```
# .NET SDK (LTS .NET 8)
winget install Microsoft.DotNet.SDK.8

# Yarn (via Corepack) – install Node.js LTS first
winget install OpenJS.NodeJS.LTS
corepack enable
corepack prepare yarn@stable --activate

# Verify
dotnet --version
yarn --version
```
### Linux Development

#### Ubuntu/Debian
```
# .NET SDK (LTS .NET 8)
sudo apt update && sudo apt install -y dotnet-sdk-8.0

# Yarn (via Corepack) – install Node.js LTS first
sudo apt install -y nodejs npm
corepack enable
corepack prepare yarn@stable --activate

# Verify
dotnet --version
yarn --version
```

#### RHEL/CentOS/Fedora
```
# .NET SDK (LTS .NET 8)
sudo dnf install -y dotnet-sdk-8.0

# Yarn (via Corepack) – install Node.js LTS first
sudo dnf install -y nodejs npm
corepack enable
corepack prepare yarn@stable --activate

# Verify
dotnet --version
yarn --version
```
## Step 2: Azure Authentication Setup

Before configuring services, authenticate with Azure:

```bash
# Login to Azure CLI
az login

# Set your subscription
az account set --subscription "your-subscription-id"

# Verify authentication
az account show
```

### Get Azure App Configuration URL

Navigate to your resource group and select the resource with prefix `appcs-` to get the configuration URL:

```bash
APP_CONFIGURATION_URL=https://[Your app configuration service name].azconfig.io
```

For reference, see the image below:
![local_development_setup_1](./images/local_development_setup_1.png)

### Required Azure RBAC Permissions

To run the application locally, your Azure account needs the following role assignments on the deployed resources:

#### App Configuration Access
```bash
# Get your principal ID
PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv)

# Assign App Configuration Data Reader role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "App Configuration Data Reader" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.AppConfiguration/configurationStores/<appconfig-name>"
```

#### Other Required Roles
Depending on the features you use, you may also need:
- **Storage Blob Data Contributor** – For Azure Storage operations  

```bash
# Assign Storage Blob Data Contributor role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<storage-account-name>"
```

- **Storage Queue Data Contributor** – For queue-based processing

```bash
# Assign Storage Queue Data Contributor role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Storage Queue Data Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<storage-account-name>"
```

- **Storage Blob Data Reader** – For read-only access to blob data

```bash
# Assign Storage Blob Data Reader role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Storage Blob Data Reader" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<storage-account-name>"
```

- **Search Index Data Contributor** – For Azure AI Search operations

```bash
# Assign Search Index Data Contributor role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Search Index Data Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Search/searchServices/<search-service-name>"
```

- **Search Service Contributor** – For managing Azure AI Search service

```bash
# Assign Search Service Contributor role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Search Service Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Search/searchServices/<search-service-name>"
```

- **Cognitive Services OpenAI User** – For Azure OpenAI access

```bash
# Assign Cognitive Services OpenAI User role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Cognitive Services OpenAI User" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<openai-service-name>"
```

- **Cognitive Services User** – For Azure AI Document Intelligence access

```bash
# Assign Cognitive Services User role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Cognitive Services User" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<document-intelligence-service-name>"
```

**Note**: RBAC permission changes can take 5-10 minutes to propagate. If you encounter "Forbidden" errors after assigning roles, wait a few minutes and try again.

## Step 3: Backend Setup

### 1. Clone the Repository

```powershell
git clone https://github.com/microsoft/Document-Knowledge-Mining-Solution-Accelerator.git
```

---

### 2. Sign In to Visual Studio
#### 1. Open Solutions in Visual Studio
Navigate to the cloned repository and open the following solution files from Visual Studio:

- **KernelMemory**
  - Path: `Document-Knowledge-Mining-Solution-Accelerator/App/kernel-memory/KernelMemory.sln`

- **Microsoft.GS.DPS**
  - Path: `Document-Knowledge-Mining-Solution-Accelerator/App/backend-api/Microsoft.GS.DPS.sln`

#### 2. Sign in to Visual Studio using your **tenant account** with the required permissions.

---

### 3. Create/Verify `appsettings.Development.json` Files

**After deploying the accelerator**, the `appsettings.Development.json` file should be created automatically. If you are using a deployed resource group that was **not deployed from your machine**, you will need to create these files manually.

#### KernelMemory Solution

1. In the **Service** project (inside the `service` folder), expand the `appsettings.json` file.
2. Confirm that `appsettings.Development.json` exists.
3. If it does not exist, create it manually by copying the sample file:

```bash
cd "Document-Knowledge-Mining-Solution-Accelerator\App\kernel-memory\service\Service"
# Copy the example file
cp appsettings.Development.json.sample appsettings.Development.json  # Linux
# or
Copy-Item appsettings.Development.json.sample appsettings.Development.json   # Windows PowerShell
```

4. Edit the `appsettings.Development.json` file with your Azure App Configuration URL:

```json
    "AppConfig": "https://<app-config-name>.azconfig.io"
```
#### Microsoft.GS.DPS Solution

1. In the **Microsoft.GS.DPS.Host** project, expand the `appsettings.json` file.
2. Confirm that `appsettings.Development.json` exists.
3. If it does not exist, create it manually by copying the sample file:

```bash
cd "Document-Knowledge-Mining-Solution-Accelerator\App\backend-api\Microsoft.GS.DPS.Host"
# Copy the example file
cp appsettings.Development.json.sample appsettings.Development.json  # Linux
# or
Copy-Item appsettings.Development.json.sample appsettings.Development.json   # Windows PowerShell
```

4. Edit the `appsettings.Development.json` file with your Azure App Configuration URL:

```json
    "AppConfig": "https://<app-config-name>.azconfig.io"
```

---

### 4. Set Startup Projects

- **KernelMemory Solution:**  
    Set **Service** (located inside the `service` folder) as the startup project to run the Kernel Memory service.

- **Microsoft.GS.DPS Solution:**  
    Set **Microsoft.GS.DPS.Host** as the startup project to run the API.

---


### 5. Assign Required Azure Roles

> **Important:**  
> These roles are required only for local debugging and development.  
> For production, ensure proper RBAC policies are applied.

1. Sign in to the [Azure Portal](https://portal.azure.com).
2. Navigate to your **Resource Group** where services are deployed.
3. Open the **App Configuration**:
   - Go to **Access control (IAM)** → **Add role assignment**.
   - Assign to:  
     `App Configuration Data Reader`
4. For **Storage Account**:
   - Go to **Access control (IAM)** → **Add role assignment**.
   - Assign to:  
     - `Storage Blob Data Contributor`  
     - `Storage Queue Data Contributor`  
     - `Storage Blob Data Reader`

---

### 6. Update Kernel Memory Endpoint in Azure App Configuration

> **Important:**  
> The following change is only for local development and debugging.  
> For production or Azure deployment, ensure the endpoint is set to `http://kernelmemory-service` to avoid misconfiguration.

1. Sign in to the [Azure Portal](https://portal.azure.com).
2. Navigate to your **App Configuration** resource within/from your deployed resource group.
3. Go to **Operations → Configuration Explorer**.
4. Search for the key:  
     `Application:Services:KernelMemory:Endpoint`
5. For local development, update its value from:
     ```
     http://kernelmemory-service
     ```
     to
     ```
     http://localhost:9001
     ```
6. Apply the changes.

---
**After running both solutions, two terminal windows will appear. Once the backend starts successfully, Swagger will start at http://localhost:9001. You can now validate the API endpoints from the Swagger UI to ensure that the backend is running correctly.**

> **Note:**  
> Always revert this value back to `http://kernelmemory-service` before running the application in Azure.

---


## Step 4: Frontend Setup

1. Open the repo in **VS Code**.
2. Navigate to the `App/frontend-app` folder and locate the `.env` file.
3. In the `.env` file, update the `VITE_API_ENDPOINT` value with your local API URL, e.g.:
     ```
     VITE_API_ENDPOINT=https://localhost:52190
     ```
4. Before installing dependencies, ensure Node.js (LTS) and Yarn are installed on your machine:
   - Recommended: install Node.js LTS (18.x or later) from https://nodejs.org
   - Install Yarn if it's not already available:
     ```powershell
     npm install -g yarn
     ```
   - Verify the installations:
     ```powershell
     node -v
     npm -v
     yarn -v
     ```
5. Install dependencies:
     ```powershell
     yarn install
     ```
6. Start the application:
     ```powershell
     yarn start
     ```

---

**The application will start at https://localhost:52190. You’re now ready to run and debug the application locally!**

---

## Troubleshooting

### Common Issues


#### Server Not Responded Issues

- While running the Kernel solution, if you encounter an error such as `server not responded` or `server not found`, it usually indicates that the required resource is not responding.   
- Ensure that the necessary **Kubernetes services** are running. If not, start the Kubernetes service and then run the Kernel solution again.

#### Permission Issues (Linux/macOS)

```bash
# Fix ownership of files
sudo chown -R $USER:$USER .
```

#### Windows-Specific Issues

```powershell
# PowerShell execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Long path support (Windows 10 1607+, run as Administrator)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

### Azure Authentication Issues

```bash
# Login to Azure CLI
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Test authentication
az account show
```

### Environment Variable Issues

```bash
# Check environment variables are loaded
env | grep AZURE  # Linux/macOS
Get-ChildItem Env:AZURE*  # Windows PowerShell

# Validate .env file format
cat .env | grep -v '^#' | grep '='  # Should show key=value pairs
```

## Related Documentation

- [Deployment Guide](DeploymentGuide.md) - Instructions for production deployment.
- [Delete Resource Group](DeleteResourceGroup.md) - Steps to safely delete the Azure resource group created for the solution.
- [PowerShell Setup](PowershellSetup.md) - Instructions for setting up PowerShell and required scripts.
- [Quota Check](QuotaCheck.md) - Steps to verify Azure quotas and ensure required limits before deployment.