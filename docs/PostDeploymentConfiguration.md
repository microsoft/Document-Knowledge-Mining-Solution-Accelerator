# Post Deployment Configuration

## Step 1: Execute the Script

### 1.1 Open PowerShell, change directory where you code cloned, then run the deploy script:  

```
cd .\Deployment\  
```  

### 1.2 Choose the appropriate command based on your deployment method:

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

### 1.3 You will be prompted for the following parameters with this Screen :  

<img src="./images/deployment/Deployment_Input_Param_01.png" width="900" alt-text="Input Parameters">

#### 1.3.1 **Email** - used for issuing certificates in Kubernetes clusters from the [Let's Encrypt](https://letsencrypt.org/) service. Email address should be valid.  

<img src="./images/deployment/Deployment_Login_02.png" width="900" alt-text="Login">

#### 1.3.2 You will be prompted to Login, Select a account and proceed to Login.

#### 1.3.3 **GO !** - Post Deployment Script executes Azure Infrastructure configuration, Application code compile and publish into Kubernetes Cluster.

#### 1.3.4 Deployment Complete
#### 🥳🎉 First, congrats on finishing Deployment!
Let's check the message and configure your model's TPM rate higher to get better performance.  
You can check the Application URL from the final console message.  
Don't miss this Url information. This is the application's endpoint URL and it should be used for your data importing process.  

<img src="./images/deployment/Deployment_Screen02.png" alt="Success Deployment" width="900">

### Manual Deployment Steps:
**Create Content Filter** - Please follow below steps
> * Navigate to project in Azure OpenAI, then go to Azure AI Foundry, select Safety + security
> * Click on Create Content Filter and set the filters to a high threshold for the following categories:
    ```
    Hate, Sexual, Self-harm, Violence
    ```
> * Please select the checkbox of profanity
> * Leave all other configurations at their default settings and click on create

## Step 2: Configure Azure OpenAI Rate Limits

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


### 2.1. Browse to the project in Azure AI Foundry, and select **each of the 2 models** within the `Deployments` menu:  
<img src="./images/deployment/Control_Model_TPM000.png" alt="Select Model" width="700">

### 2.2. Increase the TPM value for **each model** for faster report generation:  
<img src="./images/deployment/Control_Model_TPM001.png" alt="Set Token per minute" width="700">

### 3. Data Uploading and Processing
After increasing the TPM limit for each model, let's upload and process the sample documents.

Execute this command:

<img src="./images/deployment/Deployment_last_step.png" alt="Set Token per minute" width="700">
