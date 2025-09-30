# Deployment Guide

> This repository presents a solution and reference architecture for the Knowledge Mining solution accelerator. Please note that the  **provided code serves as a demonstration and is not an officially supported Microsoft offering**.
> 
> For additional security, please review how to [use Azure API Management with microservices deployed in Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/api-management/api-management-kubernetes).

## Contents
* [Prerequisites](#prerequisites)
* [Deployment Options](#deployment-options--steps)
* [Deployment](#deployment-steps)
* [Next Steps](#next-steps)

## Prerequisites

1. **[PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.4)** <small>(v5.1+)</small> - available for Windows, macOS, and Linux.

1. **[Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli)** <small>(v2.0+)</small> - command-line tool for managing Azure resources.

    2a. **kubectl** - command-line tool for interacting with Kubernetes clusters.  
        In PowerShell, run the following command:  

        az aks install-cli


    2b. **aks-preview**  - extension for Azure CLI to manage Azure Kubernetes Service.  
        In PowerShell, run the following command:  

        
        az extension add --name aks-preview
        
1. [Helm](https://helm.sh/docs/intro/install/) - package manager for Kubernetes

1. [Docker Desktop](https://docs.docker.com/get-docker/): service to containerize and publish into Azure Container Registry. Please make sure Docker desktop is running before executing Deployment script.

1. **Azure Access** - subscription-level `Owner` or `User Access Administrator` role required.

1. **Microsoft.Compute Registration**  - Ensure that **Microsoft.Compute** is registered in your Azure subscription by following these steps:  
   1. Log in to your **Azure Portal**.  
   2. Navigate to your **active Azure subscription**.  
   3. Go to **Settings** and select **Resource Providers**.
   4. Check for Microsoft.Compute and click Register if it is not already registered.
   <br>
   <img src="./images/deployment/Subscription_ResourceProvider.png" alt="ResourceProvider" width="900">

## Deployment Options & Steps

### Sandbox or WAF Aligned Deployment Options

The [`infra`](../infra) folder of the Multi Agent Solution Accelerator contains the [`main.bicep`](../infra/main.bicep) Bicep script, which defines all Azure infrastructure components for this solution.

By default, the `azd up` command uses the [`main.parameters.json`](../infra/main.parameters.json) file to deploy the solution. This file is pre-configured for a **sandbox environment** — ideal for development and proof-of-concept scenarios, with minimal security and cost controls for rapid iteration.

For **production deployments**, the repository also provides [`main.waf.parameters.json`](../infra/main.waf.parameters.json), which applies a [Well-Architected Framework (WAF) aligned](https://learn.microsoft.com/en-us/azure/well-architected/) configuration. This option enables additional Azure best practices for reliability, security, cost optimization, operational excellence, and performance efficiency, such as:

  - Enhanced network security (e.g., Network protection with private endpoints)
  - Stricter access controls and managed identities
  - Logging, monitoring, and diagnostics enabled by default
  - Resource tagging and cost management recommendations

**How to choose your deployment configuration:**

* Use the default `main.parameters.json` file for a **sandbox/dev environment**
* For a **WAF-aligned, production-ready deployment**, copy the contents of `main.waf.parameters.json` into `main.parameters.json` before running `azd up`

---

### VM Credentials Configuration

By default, the solution sets the VM administrator username and password from environment variables.
If you do not configure these values, a randomly generated GUID will be used for both the username and password.

To set your own VM credentials before deployment, use:

```sh
azd env set AZURE_ENV_VM_ADMIN_USERNAME <your-username>
azd env set AZURE_ENV_VM_ADMIN_PASSWORD <your-password>
```

> [!TIP]
> Always review and adjust parameter values (such as region, capacity, security settings and log analytics workspace configuration) to match your organization’s requirements before deploying. For production, ensure you have sufficient quota and follow the principle of least privilege for all identities and role assignments.


> [!IMPORTANT]
> The WAF-aligned configuration is under active development. More Azure Well-Architected recommendations will be added in future updates.

## Deployment Steps

Consider the following settings during your deployment to modify specific settings:

<details>
  <summary><b>Configurable Deployment Settings</b></summary>

When you start the deployment, most parameters will have **default values**, but you can update the following settings [here](../docs/CustomizingAzdParameters.md):

| **Setting**                    | **Description**                                                                      | **Default value** |
| ------------------------------ | ------------------------------------------------------------------------------------ | ----------------- |
| **Environment Name**           | Used as a prefix for all resource names to ensure uniqueness across environments.    | dkm             |
| **Azure Region**               | Location of the Azure resources. Controls where the infrastructure will be deployed. | australiaeast     |
| **Model Deployment Type**      | Defines the deployment type for the AI model (e.g., Standard, GlobalStandard).      | GlobalStandard    |
| **GPT Model Name**             | Specifies the name of the GPT model to be deployed.                                 | gpt-4.1            |
| **GPT Model Version**          | Version of the GPT model to be used for deployment.                                 | 2024-08-06        |
| **GPT Model Capacity**          | Sets the GPT model capacity.                                 | 100K        |
| **Embedding Model**                         | Sets the embedding model.                                                                      | text-embedding-3-large |
| **Embedding Model Capacity**                | Set the capacity for **embedding models** (in thousands).                                                 | 100k                    |
| **Enable Telemetry**           | Enables telemetry for monitoring and diagnostics.                                    | true              |
| **Existing Log Analytics Workspace**        | To reuse an existing Log Analytics Workspace ID instead of creating a new one.              | *(none)*          |

</details>

### Deploying with AZD

Once you've opened the project [locally](#local-environment), you can deploy it to Azure by following these steps:

1. Clone the repository or download the project code via command-line:

    ```cmd
    git clone https://github.com/microsoft/Document-Knowledge-Mining-Solution-Accelerator
    ```

    Open the cloned repository in Visual Studio Code and connect to the development container.

    ```cmd
    code .
    ```

2. Login to Azure:

    ```shell
    azd auth login
    ```

    #### To authenticate with Azure Developer CLI (`azd`), use the following command with your **Tenant ID**:

    ```sh
    azd auth login --tenant-id <tenant-id>
    ```

3. Provision and deploy all the resources:

    ```shell
    azd up
    ```

4. Provide an `azd` environment name (e.g., "ckmapp").
5. Select a subscription from your Azure account and choose a location that has quota for all the resources. 
    -- This deployment will take *7-10 minutes* to provision the resources in your account and set up the solution with sample data.
    - If you encounter an error or timeout during deployment, changing the location may help, as there could be availability constraints for the resources.

6. If you are done trying out the application, you can delete the resources by running `azd down`.

### Post Deployment Script:

The post deployment process is very straightforward and simplified via a single [deployment script](../Deployment/resourcedeployment.ps1) that completes in approximately 20-30 minutes:

### Automated Deployment Steps:
1. Configure Kubernetes Infrastructure.
2. Update Kubernetes configuration files with the FQDN, Container Image Path and Email address for the certificate management.
3. Configure AKS (deploy Cert Manager, Ingress Controller) and Deploy Images on the kubernetes cluster.
4. Docker build and push container images to Azure Container Registry.
5. Display the deployment result and following instructions.

Open PowerShell, change directory where you code cloned, then run the deploy script:  

```
cd .\Deployment\  
```  

#### Choose the appropriate command based on your deployment method:

**If you deployed using `azd up` command:**
```
.\resourcedeployment.ps1
```

**If you deployed using custom templates, ARM/Bicep deployments, or `az deployment group` commands:**
```
.\resourcedeployment.ps1 -ResourceGroupName "<your-resource-group-name>"
```

> **Note:** Replace `<your-resource-group-name>` with the actual name of the resource group containing your deployed Azure resources.

> **💡 Tip**: Since this guide is for azd deployment, you'll typically use the first command without the `-ResourceGroupName` parameter.

If you run into issue with PowerShell script file not being digitally signed, you can execute below command:

```
powershell.exe -ExecutionPolicy Bypass -File ".\resourcedeployment.ps1"
```

You will be prompted for the following parameters with this Screen :  
<img src="./images/deployment/Deployment_Input_Param_01.png" width="900" alt-text="Input Parameters">

1. **Email** - used for issuing certificates in Kubernetes clusters from the [Let's Encrypt](https://letsencrypt.org/) service. Email address should be valid.  

<img src="./images/deployment/Deployment_Login_02.png" width="900" alt-text="Login">

2. You will be prompted to Login, Select a account and proceed to Login.

3. **GO !** - Post Deployment Script executes Azure Infrastructure configuration, Application code compile and publish into Kubernetes Cluster.

### Manual Deployment Steps:
**Create Content Filter** - Please follow below steps
> * Navigate to project in Azure OpenAI, then go to Azure AI Foundry, select Safety + security
> * Click on Create Content Filter and set the filters to a high threshold for the following categories:
    ```
    Hate, Sexual, Self-harm, Violence
    ```
> * Please select the checkbox of profanity
> * Leave all other configurations at their default settings and click on create

### Deployment Complete
#### 🥳🎉 First, congrats on finishing Deployment!
Let's check the message and configure your model's TPM rate higher to get better performance.  
You can check the Application URL from the final console message.  
Don't miss this Url information. This is the application's endpoint URL and it should be used for your data importing process.  

<img src="./images/deployment/Deployment_Screen02.png" alt="Success Deployment" width="900">

## Next Steps

### 1. Configure Azure OpenAI Rate Limits

> **Capacity Note:**
> * The deployment script creates models with a setting of 1 token per minute (TPM) rate limit.
> * Faster performance can be achieved by increasing the TPM limit with Azure AI Foundry.
> * Capacity varies for [regional quota limits](https://learn.microsoft.com/en-us/azure/ai-services/openai/quotas-limits#regional-quota-limits) as well as for [provisioned throughput](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/provisioned-throughput).
> * As a starting point, we recommend the following quota threshold be set up for this service run.  

| Model Name             | TPM Threshold |
|------------------------|---------------|
| GPT-4.1-mini           | 100K TPM      |
| text-embedding-3-large | 200K TPM      |


> **⚠️ Warning:**  **Insufficient quota can cause failures during the upload process.** Please ensure you have the recommended capacity or request for additional capacity before start uploading the files.


1. Browse to the project in Azure AI Foundry, and select **each of the 2 models** within the `Deployments` menu:  
<img src="./images/deployment/Control_Model_TPM000.png" alt="Select Model" width="700">

2. Increase the TPM value for **each model** for faster report generation:  
<img src="./images/deployment/Control_Model_TPM001.png" alt="Set Token per minute" width="700">

### 2. Data Uploading and Processing
After increasing the TPM limit for each model, let's upload and process the sample documents.
```
cd .\Deployment\
```

Execute uploadfiles.ps1 file with **-EndpointUrl** parameter as URL in console message.

```
.\uploadfiles.ps1 -EndpointUrl https://kmgs<your dns name>.<datacenter>.cloudapp.azure.com
```

If you run into issue with PowerShell script file not being digitally signed, you can execute below command:

```
powershell.exe -ExecutionPolicy Bypass -File ".\uploadfiles.ps1" -EndpointUrl https://kmgs<your dns name>.<datacenter>.cloudapp.azure.com
```