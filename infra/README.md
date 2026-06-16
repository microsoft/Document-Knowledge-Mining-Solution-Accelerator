# Document Knowledge Mining — Infrastructure

This folder contains the Bicep/AVM infrastructure for the Document Knowledge Mining (DKM) Solution Accelerator. The structure follows the [`mcaps-microsoft/accelerator-toolkit-core`](https://github.com/mcaps-microsoft/accelerator-toolkit-core) reference pattern: a thin router that delegates to one of two implementation flavors.

---

## At a glance

| Flavor | Path | Description |
|--------|------|-------------|
| **AVM** | `avm/` | Wrappers around [Azure Verified Modules](https://aka.ms/avm). Default; recommended for production / WAF-aligned deployments. |
| **Vanilla Bicep** | `bicep/` | Native `Microsoft.*` resources. Lightweight; useful when AVM coverage or version is unavailable. |

Both flavors expose identical parameters and outputs. Selection is runtime-driven via the `deploymentFlavor` parameter on `main.bicep`.

---

## Folder structure

```
infra/
├── main.bicep                  # Router — selects avm/ or bicep/ via deploymentFlavor param
├── main.json                   # Compiled router (used by "Deploy to Azure" / portal)
├── main.parameters.json        # Default parameters (all WAF toggles OFF)
├── main.waf.parameters.json    # WAF-aligned parameters (private networking + monitoring + scalability ON)
├── README.md
├── avm/
│   ├── main.bicep              # AVM-flavor orchestrator
│   ├── main.json               # Compiled AVM orchestrator
│   └── modules/
│       ├── ai/                 # openai, document-intelligence, ai-search
│       ├── compute/            # aks, container-registry, virtual-machine (jumpbox)
│       ├── data/               # storage-account, cosmos-db, app-configuration
│       ├── identity/           # (reserved — SAI migration removed workload UAI)
│       ├── monitoring/         # log-analytics, app-insights
│       └── networking/         # virtual-network, private-dns-zone, private-endpoint, bastion-host
├── bicep/
│   ├── main.bicep              # Vanilla-Bicep-flavor orchestrator
│   ├── main.json               # Compiled vanilla orchestrator
│   └── modules/                # Same domain folders as avm/
├── scripts/
│   ├── build/                  # build-bicep.{ps1,sh} — recompile all 3 entrypoints
│   ├── pre-provision/          # Hooks (reserved for future scripts)
│   ├── post-provision/         # Hooks (reserved for future scripts)
│   └── utilities/              # Shared helpers (reserved)
└── images/                     # Diagrams referenced from documentation
```

---

## Quick start

### Option A — `azd` (recommended)

```bash
# 1. Authenticate
azd auth login
az login

# 2. Create / select an azd environment
azd env new dkm-dev      # or:   azd env select dkm-dev

# 3. Set required environment variables
azd env set AZURE_LOCATION                   eastus
azd env set AZURE_ENV_AI_SERVICE_LOCATION    eastus2
azd env set AZURE_ENV_MODEL_DEPLOYMENT_TYPE  GlobalStandard
azd env set AZURE_ENV_GPT_MODEL_NAME         gpt-4.1-mini
azd env set AZURE_ENV_GPT_MODEL_VERSION      2025-04-14
azd env set AZURE_ENV_GPT_MODEL_CAPACITY     100
azd env set AZURE_ENV_EMBEDDING_MODEL_NAME           text-embedding-3-large
azd env set AZURE_ENV_EMBEDDING_MODEL_VERSION        1
azd env set AZURE_ENV_EMBEDDING_DEPLOYMENT_CAPACITY  100
azd env set AZURE_ENV_ENABLE_TELEMETRY       true

# 4. Provision
azd provision
```

`azd` reads parameter bindings from `infra/main.parameters.json`, substitutes the `${AZURE_ENV_*}` placeholders from your azd env, and submits `main.bicep` (the router) to Azure.

### Option B — `az deployment group` (direct ARM)

```bash
RG=rg-dkm-dev
az group create -n $RG -l eastus

az deployment group create \
  -g $RG \
  -f infra/main.bicep \
  -p @infra/main.parameters.json \
  -p solutionName=dkmdev \
  -p azureAiServiceLocation=eastus2
```

---

## Choosing a flavor

```bash
# AVM (default — no param needed)
azd env set DEPLOYMENT_FLAVOR avm
# or skip; 'avm' is the default

# Vanilla Bicep
azd env set DEPLOYMENT_FLAVOR bicep
```

> **Note:** `deploymentFlavor` is bound in `main.parameters.json` via `${DEPLOYMENT_FLAVOR=bicep}` (defaults to `bicep` if unset). Override with `azd env set DEPLOYMENT_FLAVOR avm` or pass `-p deploymentFlavor=avm` on the `az deployment group create` command line.

---

## Deployment modes — default vs WAF

| File | Mode | Private networking | Monitoring | Redundancy | Scalability |
|------|------|:---:|:---:|:---:|:---:|
| `main.parameters.json`     | Default (dev / cost-optimized) | off | off | off | off |
| `main.waf.parameters.json` | WAF-aligned (production)       | **on**  | **on**  | off | **on** |

WAF mode flips the four `enable*` toggles in the router; both flavors honor them. To deploy in WAF mode with `azd`, point `azd provision` at the WAF parameter file, or with the CLI:

```bash
az deployment group create \
  -g $RG \
  -f infra/main.bicep \
  -p @infra/main.waf.parameters.json
```

WAF mode additionally requires:

- `AZURE_ENV_VM_ADMIN_USERNAME` and `AZURE_ENV_VM_ADMIN_PASSWORD` (jumpbox credentials)
- `AZURE_ENV_VM_SIZE` (default `Standard_D2s_v5`)

---

## WAF feature toggles (router parameters)

The router accepts four independent toggles. Set any combination to mix features without committing to the full WAF preset.

| Param | Default | Effect when `true` |
|-------|:---:|---|
| `enablePrivateNetworking` | `false` | Deploy VNet + subnets + private endpoints + Bastion + jumpbox VM. **Note:** `publicNetworkAccess` remains `Enabled` on all resources because AKS pods cannot reliably resolve private DNS zones in shared subscriptions. Security is enforced via RBAC (System-Assigned Identity) + connection-string auth (Cosmos). Private endpoints provide optimized in-VNet routing where DNS resolution succeeds. |
| `enableMonitoring`        | `false` | Deploy Log Analytics + Application Insights; wire diagnostic settings on bastion, AKS, AI Search, jumpbox. |
| `enableRedundancy`        | `false` | Enable zone-redundancy and HA failover (e.g., Cosmos secondary region pair). |
| `enableScalability`       | `false` | Use larger SKUs (e.g., AI Search `standard` instead of `basic`). |

---

## Recompiling `main.json`

After editing any `.bicep` file, regenerate the compiled `main.json` artifacts so the "Deploy to Azure" button and direct-ARM workflows pick up the change.

```powershell
# Windows / PowerShell
pwsh -NoProfile -File infra\scripts\build\build-bicep.ps1
```

```bash
# Linux / macOS / WSL
bash infra/scripts/build/build-bicep.sh
```

The script compiles all three entrypoints (`main.bicep`, `avm/main.bicep`, `bicep/main.bicep`) and writes the resulting `main.json` next to each source. Requires the `az` CLI with the `bicep` extension installed.

---

## Identity & authentication

The DKM accelerator uses **System-Assigned Managed Identities (SAI)** for all runtime authentication:

| Component | Identity | How pods authenticate |
|-----------|----------|----------------------|
| AKS workload pods | VMSS System-Assigned Identity | `DefaultAzureCredential` → IMDS (no `AZURE_CLIENT_ID` needed) |
| AKS kubelet | Kubelet UAI (auto-created by AKS) | ACR image pulls only |
| Deployer (you) | Azure AD User | `azd` / `az` CLI + PS1 docker push (AcrPush role) |

RBAC roles are assigned by `Deployment/resourcedeployment.ps1` post-provision to the VMSS SAI. The 7 required data-plane roles are:

1. App Configuration Data Reader (RG scope)
2. Storage Blob Data Contributor (Storage account)
3. Storage Queue Data Contributor (Storage account)
4. Cognitive Services OpenAI User (OpenAI account)
5. Search Index Data Contributor (AI Search)
6. Search Service Contributor (AI Search)
7. Cognitive Services User (Document Intelligence account)

> **Note:** Cosmos DB uses connection-string auth (not RBAC). The connection string is stored in App Configuration at deploy time.

---

## Known limitations (AKS + Private Endpoints)

When `enablePrivateNetworking=true`, the AVM flavor deploys VNet, subnets, and private endpoints. However, AKS pods may not resolve private DNS zones correctly in all environments (e.g., CSA-CTO shared subscriptions where APIM hub intercepts DNS). To ensure reliable end-to-end connectivity:

1. **Public access remains enabled** on all resources — pods connect via public endpoints.
2. **Cosmos DB PE is intentionally disabled** — Cosmos enforces PE-only access when a PE exists, but AKS pods resolve the FQDN to the public IP (no A record in private DNS zone), causing `403 blocked by network firewall`.
3. **Security is not compromised** — all access is gated by RBAC (SAI) or connection-string secrets stored in App Configuration (never exposed publicly).
4. **Private endpoints still provide value** — optimized routing for traffic that does resolve via private DNS (e.g., VNet-integrated services, jumpbox).

This matches the pattern used by the [Agentic SA reference repo](https://github.com/microsoft/agentic-applications-for-unified-data-foundation-solution-accelerator/tree/psl/infra-restructure-new), which also keeps `publicNetworkAccess: Enabled` on AI Search and AI Foundry for similar DNS resolution limitations.

---

## Reference

- **Structure pattern**: [`mcaps-microsoft/accelerator-toolkit-core`](https://github.com/mcaps-microsoft/accelerator-toolkit-core) — the canonical infra layout this repo follows.
- **Azure Verified Modules**: [aka.ms/avm](https://aka.ms/avm) — registry of well-architected modules consumed by the AVM flavor.
- **Bicep**: [aka.ms/bicep](https://aka.ms/bicep) — language documentation and CLI reference.
