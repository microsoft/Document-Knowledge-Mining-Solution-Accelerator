# Local Setup Guide

Follow these steps to set up and debug the application locally.

---

## Backend Setup

### 1. Clone the Repository

```powershell
git clone https://github.com/microsoft/Document-Knowledge-Mining-Solution-Accelerator.git
```

---

### 2. Sign In to Visual Studio

- Open the **KernelMemory** and **Microsoft.GS.DPS** solutions in Visual Studio.
- Sign in using your tenant account with the required permissions.

---

### 3. Verify `appsettings.Development.json`

After deploying the accelerator, the `appsettings.Development.json` file will be created automatically.

- **KernelMemory Solution:**  
    Expand the `appsettings.json` file under the **Service** project (inside the `service` folder) and confirm that `appsettings.Development.json` exists.

- **Microsoft.GS.DPS Solution:**  
    Expand the `appsettings.json` file under the **Microsoft.GS.DPS.Host** project and confirm that `appsettings.Development.json` exists.

---

### 4. Set Startup Projects

- **KernelMemory Solution:**  
    Set **Service** (located inside the `service` folder) as the startup project to run the Kernel Memory service.

- **Microsoft.GS.DPS Solution:**  
    Set **Microsoft.GS.DPS.Host** as the startup project to run the API.

---

### 5. Assign Required Azure Roles

To enable local debugging and ensure your application can access necessary Azure resources, assign the following roles to your Microsoft Entra ID in the respective services within your deployed resource group in the Azure portal:

- **App Configuration**
    - App Configuration Data Reader
- **Storage Account**
    - Storage Blob Data Contributor
    - Storage Queue Data Contributor
    - Storage Blob Data Reader

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

> **Note:**  
> Always revert this value back to `http://kernelmemory-service` before running the application in Azure.

---

## Frontend Setup

1. Open the repo in **VS Code**.
2. Navigate to the `App/frontend-app` folder and locate the `.env` file.
3. In the `.env` file, update the `VITE_API_ENDPOINT` value with your local API URL, e.g.:
     ```
     VITE_API_ENDPOINT=https://localhost:52190
     ```
4. Install dependencies:
     ```powershell
     yarn install
     ```
5. Start the application:
     ```powershell
     yarn start
     ```

---

**You're now ready to run and debug the application locally!**