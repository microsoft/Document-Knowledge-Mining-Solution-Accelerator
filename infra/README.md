# Deploying the infrastructure

You can deploy the Kernel Memory infrastructure to Azure by clicking the button below. This will create required
resources. We recommend to create a new resource group for each deployment.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2Fkernel-memory%2Fmain%2Finfra%2Fmain.json)

<details>

<summary>Tips for customizing the deployment</summary>

Resources are deployed with an opinionated set of configurations. You can modify services on Azure portal or you can
reuse and customize the Bicep files starting from [infra/main.bicep](main.bicep).

> [!TIP]
> The `Deploy to Azure` button uses the [infra/main.json](main.json) file, which is a compiled version of
> [infra/main.bicep](main.bicep). Please note that the `main.json` file is not updated automatically when you
> make changes to `main.bicep` file.
>
> You can use the `az bicep build -f main.bicep` command to compile the Bicep file to a json file.
>
> - [Click here](https://learn.microsoft.com/cli/azure/install-azure-cli) for `az` install instructions
> - [Click here](https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-cli) for Bicep CLI commands

</details>

After the deployment is complete, you will see the following resources in your resource group:

- Application Insights
- Container Apps Environment
- Log Analytics workspace
- Search service
- Container App
- Managed Identity
- Storage account

You can start using Kernel Memory immediately after deployment. Use `Application Url` from Container App instance page as Kernel Memory's endpoint. Refer [to this screenshot](./images/ACA-ApplicationUrl.png) if you need help finding Application Url value.

Kernel Memory web service is deployed with `AuthenticationType` set to `APIKey` and default API keys are random GUIDs. Each request requires the `Authorization` HTTP header, passing one of the two keys.

> [!WARNING]
> It is highly recommended to change the default API keys after deployment. You can do this by updating the
> `KernelMemory__ServiceAuthorization__AccessKey1` and `KernelMemory__ServiceAuthorization__AccessKey2` > **environment variables** in the Container App.
>
> Refer [to this screenshot](./images/ACA-EnvVar.png) or to the documentation
> page: [Manage environment variables on Azure Container Apps](https://learn.microsoft.com/azure/container-apps/environment-variables?tabs=portal)
> if you need help finding and changing environment variables.

> [!TIP]
> The easiest way to start using Kernel Memory API is to use Swagger UI. You can access it by navigating to
> `{Application Url}/swagger/index.html` in your browser. Replace `km-service-example.example.azurecontainerapps.io`
> with your Application Url value.

Here is an example of how to create a `MemoryWebClient` instance and start using Kernel Memory web service:

```csharp
var memory = new MemoryWebClient(
    "https://km-service-example.example.azurecontainerapps.io",
    apiKey: "...your WebServiceAuthorizationKey1...");
```

We recommend reviewing the [examples](https://github.com/microsoft/kernel-memory/tree/main/examples) included in the repository, e.g. starting from
[001-dotnet-WebClient](https://github.com/microsoft/kernel-memory/tree/main/examples/001-dotnet-WebClient).

---

# Infrastructure Modules — Document Knowledge Mining Solution Accelerator

This folder contains the modular Bicep infrastructure for the **Document Knowledge Mining (DKM) Solution Accelerator**.

## Overview

Two flavors are available:

| Flavor | Path | Description |
|--------|------|-------------|
| **Vanilla Bicep** | `bicep/` | Lightweight modules using native Bicep resources directly. Default flavor. |
| **AVM** | `avm/` | Modules wrapping [Azure Verified Modules](https://aka.ms/avm) for WAF-aligned, enterprise-grade deployments |

Both flavors follow the same folder structure and naming conventions, so switching between them requires minimal changes to your orchestrator.

---

## Folder Structure

```
infra/
├── avm/
│   ├── main.bicep                    # Orchestrator (AVM flavor)
│   └── modules/
│       ├── ai/                       # AI Search, OpenAI, Document Intelligence
│       ├── compute/                  # AKS, Container Registry, Virtual Machine
│       ├── data/                     # Storage Account, Cosmos DB, App Configuration
│       ├── fabric/                   # Microsoft Fabric
│       ├── identity/                 # RBAC, Managed Identities
│       ├── monitoring/               # Log Analytics, App Insights
│       ├── networking/               # VNet, Private Endpoints, Bastion
│       └── security/                 # Key Vault
├── bicep/
│   ├── main.bicep                    # Orchestrator (Vanilla Bicep flavor)
│   └── modules/                      # Same domain folders as AVM
├── scripts/
│   ├── build/                        # build-bicep.{ps1,sh} — recompile entrypoints
│   ├── pre-provision/                # Pre-provision hooks
│   ├── post-provision/               # Post-provision hooks
│   └── utilities/                    # Shared helpers
├── images/                           # Diagrams referenced from documentation
├── main.bicep                        # Router (selects avm/ or bicep/ based on param)
├── main.json                         # Compiled router (used by "Deploy to Azure" / portal)
├── main.parameters.json              # Default parameters
└── main.waf.parameters.json          # WAF-aligned parameters (VNet, PE, etc.)
```

Modules are organized by **service domain** (ai, compute, data, etc.). Both flavors expose identical parameters and outputs. Selection is runtime-driven via the `deploymentFlavor` parameter on `main.bicep`.

---

## How to Use

### 1. Choosing a flavor

```bash
# Vanilla Bicep (default)
azd env set DEPLOYMENT_FLAVOR bicep

# AVM
azd env set DEPLOYMENT_FLAVOR avm

# AVM with WAF (private networking, monitoring, scalability)
azd env set DEPLOYMENT_FLAVOR avm-waf
```

> **Note:** `deploymentFlavor` defaults to `bicep` in `main.parameters.json` and to `avm-waf` in `main.waf.parameters.json`. Valid values: `bicep`, `avm`, `avm-waf`. Override via `azd env set` or `-p deploymentFlavor=<value>` on `az deployment group create`.

### 2. Use the router for dual-mode support

The root `main.bicep` acts as a router — it selects between `avm/main.bicep` and `bicep/main.bicep` based on the `deploymentFlavor` parameter, allowing the same deployment command to target either flavor.

---

## Role Assignments

All role assignments are centralized in `identity/role-assignments.bicep` for auditability. Individual modules do **not** create their own RBAC — the orchestrator wires principal IDs and resource IDs into the single role-assignments module.

---

## Contributing New Modules

When adding a new module:

1. Place it in the appropriate domain folder (`ai/`, `compute/`, `data/`, etc.)
2. Accept `solutionName` as a parameter and derive the resource name internally
3. Use descriptive `@description()` decorators on all parameters
4. Output the resource's key properties (name, id, endpoint, principalId, etc.)
5. Keep it generic — no app-specific or accelerator-specific logic
6. Add it to both `avm/` and `bicep/` flavors where applicable
7. Test with `az bicep build` before committing
