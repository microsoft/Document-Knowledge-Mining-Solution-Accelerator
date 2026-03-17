# Data Migration

Migrates data from **Azure AI Search**, **Cosmos DB** (MongoDB API), and **Azure Blob Storage**
in a source resource group into target services in a new resource group.

The script automatically handles RBAC role assignment/revocation, retry logic, pagination,
content-type preservation for blobs, and Windows long-path support.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- Cosmos DB MongoDB connection strings for source and/or target
- Your Azure AD account needs **Owner** or **User Access Administrator** on the source/target
  resource groups so the script can temporarily assign the required RBAC roles (see below)


## Setup

```bash
cd Deployment/data_migration

# Create virtual environment
python -m venv .venv

# Activate virtual environment
# Windows (PowerShell)
.venv\Scripts\Activate.ps1

# Windows (Command Prompt)
.venv\Scripts\activate.bat

# macOS / Linux
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## Commands for migration

The script prompts interactively for required endpoints, connection strings, resource groups,
and subscription ID based on the chosen command and flags.

```bash
# Export from source resource group
python migrate.py export

# Import into target resource group
python migrate.py import

# Full migration (both steps)
python migrate.py export-import
```

**Optional flags:** `--search-only`, `--cosmos-only`, `--blob-only`, `--verbose`

### Example — full export

```
$ python migrate.py export
Enter SOURCE Search Endpoint (e.g. https://<name>.search.windows.net): https://my-source.search.windows.net
Enter SOURCE Cosmos DB connection string: mongodb://...
Enter SOURCE Storage Account name: mysourcestorage
Enter your Azure Subscription ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Enter the resource group for source search service 'my-source': rg-source
Enter the resource group for source storage account 'mysourcestorage': rg-source
...
```

### Example — blob-only import

```
$ python migrate.py import --blob-only
Enter TARGET Storage Account name: mytargetstorage
Enter your Azure Subscription ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Enter the resource group for target storage account 'mytargetstorage': rg-target
...
```

### Obtaining Azure Credentials

| Value | How to Find |
|---|---|
| **Search Endpoint** | Azure Portal → **AI Search** service → **Overview** → **URL** (e.g. `https://<name>.search.windows.net`) |
| **Cosmos DB Connection String** | Azure Portal → **Azure Cosmos DB** account → **Settings** → **Connection strings** → **Primary Connection String** |
| **Storage Account Name** | Azure Portal → **Storage accounts** → the account name shown in the list (e.g. `mystorage123`, not a URL) |
| **Subscription ID** | Azure Portal → **Subscriptions** → copy the **Subscription ID** column |
| **Resource Group** | Azure Portal → the resource's **Overview** page → **Resource group** field |

## What Gets Migrated

| Service | Data |
|---|---|
| Azure AI Search | All index schemas + all documents (including embeddings) |
| Cosmos DB | `DPS.ChatHistory` and `DPS.Documents` collections |
| Azure Blob Storage | All containers and blobs with content-type metadata preserved |


## Export Format

```
exported_data/
├── search/
│   ├── <index>_schema.json          # Index definition
│   └── <index>_documents.jsonl      # One JSON document per line
├── cosmos/
│   ├── ChatHistory.jsonl
│   ├── ChatHistory.checksum
│   ├── Documents.jsonl
│   └── Documents.checksum
└── blobstorage/
    ├── <container>/
    │   ├── __blob_metadata__.json   # Content-type sidecar
    │   └── <blob files...>          # Original directory structure preserved
    └── <container>/
        └── ...
```

## Configuration

The script prompts for these values interactively based on the command:

| Prompt | When Asked | Description |
|---|---|---|
| Source Search Endpoint | export | Source Azure AI Search endpoint URL |
| Source Cosmos DB connection string | export | Source Cosmos DB MongoDB connection string |
| Source Storage Account name | export | Source Azure Blob Storage account name |
| Target Search Endpoint | import | Target Azure AI Search endpoint URL |
| Target Cosmos DB connection string | import | Target Cosmos DB MongoDB connection string |
| Target Storage Account name | import | Target Azure Blob Storage account name |
| Azure Subscription ID | export/import (Search or Blob) | Subscription for RBAC role management |
| Resource group | export/import (Search or Blob) | Resource group for each Search/Storage service |

---
For complete deployment instructions, refer to the  [Deployment Guide](../../docs/DeploymentGuide.md).
