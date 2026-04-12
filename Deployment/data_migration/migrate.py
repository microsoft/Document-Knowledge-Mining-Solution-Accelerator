"""
Data Migration Script for Document Knowledge Mining Solution Accelerator.

Exports data from Azure AI Search, Cosmos DB (MongoDB API), and Azure Blob
Storage in a source resource group and imports it into target services in a
new resource group.

Usage:
    python migrate.py export          # Export from source
    python migrate.py import          # Import into target
    python migrate.py export-import   # Full migration (export then import)

All required configuration is collected interactively at runtime.
"""

import argparse
import hashlib
import json
import logging
import platform
import subprocess
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger("dkm_migration")

# Suppress noisy Azure credential fallback debug logs
logging.getLogger("azure.identity").setLevel(logging.WARNING)
logging.getLogger("azure.core.pipeline.policies.http_logging_policy").setLevel(logging.WARNING)


# ---------------------------------------------------------------------------
# Configuration helpers
# ---------------------------------------------------------------------------

def get_export_dir() -> Path:
    """Return the configured export directory, creating it if needed."""
    export_dir = Path("./exported_data")
    export_dir.mkdir(parents=True, exist_ok=True)
    return export_dir


def _long_path(p: Path) -> Path:
    """Return a Windows extended-length path to bypass the 260-char MAX_PATH limit."""
    if platform.system() != "Windows":
        return p
    s = str(p.resolve())
    if not s.startswith("\\\\?\\"):
        s = "\\\\?\\" + s
    return Path(s)


def _format_duration(seconds: float) -> str:
    """Return a human-readable duration string."""
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    parts = []
    if h:
        parts.append(f"{h}h")
    if m:
        parts.append(f"{m}m")
    parts.append(f"{s}s")
    return " ".join(parts)


def _check_azure_login() -> None:
    """Verify Azure credentials are available; trigger 'az login' if not."""
    from azure.identity import DefaultAzureCredential, AzureCliCredential
    from azure.core.exceptions import ClientAuthenticationError

    try:
        credential = DefaultAzureCredential()
        credential.get_token("https://management.azure.com/.default")
        logger.info("Azure credentials verified.")
        return
    except (ClientAuthenticationError, Exception):
        logger.warning("Azure credentials not found. Launching 'az login'...")

    try:
        # Use shell=True so Windows can resolve 'az.cmd' via PATH
        result = subprocess.run("az login", shell=True, check=False)
        if result.returncode != 0:
            logger.error("'az login' failed. Please log in manually and re-run the script.")
            sys.exit(1)
    except FileNotFoundError:
        logger.error(
            "Azure CLI ('az') is not installed or not on PATH. "
            "Install it from https://aka.ms/installazurecli, then run this script again."
        )
        sys.exit(1)

    # Retry credential check after login
    try:
        credential = AzureCliCredential()
        credential.get_token("https://management.azure.com/.default")
        logger.info("Azure credentials verified after login.")
    except Exception as e:
        logger.error("Authentication still failed after 'az login': %s", e)
        sys.exit(1)


def _get_search_credential():
    """Return a DefaultAzureCredential for RBAC-based Azure Search access."""
    from azure.identity import DefaultAzureCredential

    return DefaultAzureCredential()


# ---------------------------------------------------------------------------
# Azure RBAC Role Management
# ---------------------------------------------------------------------------

SEARCH_ROLES = [
    "Search Index Data Contributor",
    "Search Service Contributor",
]

BLOB_ROLES = [
    "Storage Blob Data Contributor",
]


def _get_search_service_name(endpoint: str) -> str:
    """Extract the search service name from an endpoint URL."""
    from urllib.parse import urlparse
    return urlparse(endpoint).hostname.split(".")[0]


def _get_signed_in_user_id() -> str:
    """Get the object ID of the currently signed-in Azure CLI user."""
    result = subprocess.run(
        "az ad signed-in-user show --query id -o tsv",
        shell=True, capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        logger.error("Failed to get signed-in user info: %s", result.stderr.strip())
        sys.exit(1)
    return result.stdout.strip()


def _prompt(prompt_text: str) -> str:
    """Interactively prompt the user for a required value."""
    value = input(prompt_text).strip()
    if not value:
        logger.error("A value is required. Aborting.")
        sys.exit(1)
    return value


def _build_search_scope(
    subscription_id: str, resource_group: str, service_name: str
) -> str:
    """Build the Azure resource ID for a search service."""
    return (
        f"/subscriptions/{subscription_id}/resourceGroups/{resource_group}"
        f"/providers/Microsoft.Search/searchServices/{service_name}"
    )


def _check_role_assigned(scope: str, role: str, assignee_id: str) -> bool:
    """Return True if the role is already assigned at the given scope."""
    result = subprocess.run(
        f'az role assignment list --assignee "{assignee_id}" --role "{role}" '
        f'--scope "{scope}" --query "length(@)" -o tsv',
        shell=True, capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        return False
    count = result.stdout.strip()
    return count.isdigit() and int(count) > 0


def _assign_role(scope: str, role: str, assignee_id: str) -> bool:
    """Assign a role if not already present. Returns True if newly assigned."""
    if _check_role_assigned(scope, role, assignee_id):
        logger.info("  Role '%s' is already assigned.", role)
        return False

    logger.info("  Assigning role '%s'...", role)
    result = subprocess.run(
        f'az role assignment create --assignee-object-id "{assignee_id}" '
        f'--assignee-principal-type "User" --role "{role}" --scope "{scope}" -o none',
        shell=True, capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        logger.error("  Failed to assign role '%s': %s", role, result.stderr.strip())
        sys.exit(1)
    logger.info("  Role '%s' assigned successfully.", role)
    return True


def _revoke_role(scope: str, role: str, assignee_id: str) -> None:
    """Remove a single role assignment."""
    logger.info("  Revoking role '%s'...", role)
    result = subprocess.run(
        f'az role assignment delete --assignee "{assignee_id}" --role "{role}" '
        f'--scope "{scope}" -o none',
        shell=True, capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        logger.warning("  Failed to revoke role '%s': %s", role, result.stderr.strip())
    else:
        logger.info("  Role '%s' revoked.", role)


def _ensure_search_roles(
    endpoint: str, label: str, subscription_id: str, principal_id: str
) -> list:
    """Ensure required RBAC roles on a search service.

    Returns a list of dicts describing only the *newly* assigned roles
    so they can be revoked after migration.
    """
    service_name = _get_search_service_name(endpoint)
    resource_group = _prompt(
        f"Enter the resource group for {label} search service '{service_name}': "
    )

    scope = _build_search_scope(subscription_id, resource_group, service_name)
    newly_assigned: list = []

    logger.info(
        "Checking RBAC roles for %s search service '%s'...", label, service_name
    )
    for role in SEARCH_ROLES:
        if _assign_role(scope, role, principal_id):
            newly_assigned.append(
                {"scope": scope, "role": role, "principal_id": principal_id}
            )

    if newly_assigned:
        logger.info("Waiting for role assignments to propagate...")
        time.sleep(15)

    return newly_assigned


def _revoke_roles(assignments: list) -> None:
    """Revoke all temporarily assigned roles."""
    if not assignments:
        return
    logger.info("=== REVOKING TEMPORARY ROLE ASSIGNMENTS ===")
    for a in assignments:
        _revoke_role(a["scope"], a["role"], a["principal_id"])
    logger.info("=== ROLE REVOCATION COMPLETE ===")


def _build_storage_scope(
    subscription_id: str, resource_group: str, account_name: str
) -> str:
    """Build the Azure resource ID for a storage account."""
    return (
        f"/subscriptions/{subscription_id}/resourceGroups/{resource_group}"
        f"/providers/Microsoft.Storage/storageAccounts/{account_name}"
    )


def _ensure_blob_roles(
    account_name: str, label: str, subscription_id: str, principal_id: str
) -> list:
    """Ensure required RBAC roles on a storage account.

    Returns a list of dicts describing only the *newly* assigned roles
    so they can be revoked after migration.
    """
    resource_group = _prompt(
        f"Enter the resource group for {label} storage account '{account_name}': "
    )

    scope = _build_storage_scope(subscription_id, resource_group, account_name)
    newly_assigned: list = []

    logger.info(
        "Checking RBAC roles for %s storage account '%s'...", label, account_name
    )
    for role in BLOB_ROLES:
        if _assign_role(scope, role, principal_id):
            newly_assigned.append(
                {"scope": scope, "role": role, "principal_id": principal_id}
            )

    if newly_assigned:
        logger.info("Waiting for role assignments to propagate...")
        time.sleep(15)

    return newly_assigned


# ---------------------------------------------------------------------------
# Azure AI Search - Export
# ---------------------------------------------------------------------------

def export_search(export_dir: Path, endpoint: str) -> None:
    """Export all documents from Azure AI Search indexes."""
    from azure.search.documents.indexes import SearchIndexClient

    credential = _get_search_credential()

    index_client = SearchIndexClient(endpoint=endpoint, credential=credential)

    # Auto-discover all indexes
    logger.info("Auto-discovering search indexes...")
    index_names = [idx.name for idx in index_client.list_indexes()]

    if not index_names:
        logger.warning("No search indexes found to export.")
        return

    logger.info("Indexes to export: %s", index_names)
    search_dir = export_dir / "search"
    search_dir.mkdir(parents=True, exist_ok=True)

    for index_name in index_names:
        logger.info("Exporting search index: %s", index_name)
        _export_search_index_schema(index_client, index_name, search_dir)
        _export_search_index_documents(endpoint, credential, index_name, search_dir)


def _export_search_index_schema(
    index_client, index_name: str, search_dir: Path
) -> None:
    """Export the index definition (schema) so it can be recreated."""
    try:
        index_def = index_client.get_index(index_name)
        # Use the SDK's built-in serialization for full fidelity
        schema = index_def.as_dict()

        schema_path = search_dir / f"{index_name}_schema.json"
        schema_path.write_text(
            json.dumps(schema, indent=2, default=str), encoding="utf-8"
        )
        logger.info("  Schema saved to %s", schema_path)
    except Exception:
        logger.exception("  Failed to export schema for index '%s'", index_name)


def _export_search_index_documents(
    endpoint: str, credential, index_name: str, search_dir: Path
) -> None:
    """Export all documents from a search index using paginated search with retries."""
    from azure.search.documents import SearchClient

    client = SearchClient(
        endpoint=endpoint, index_name=index_name, credential=credential
    )
    docs_path = search_dir / f"{index_name}_documents.jsonl"
    doc_count = 0
    page_size = 500
    skip = 0
    max_retries = 3
    consecutive_empty = 0

    with open(docs_path, "w", encoding="utf-8") as f:
        while True:
            page_docs = []
            for attempt in range(1, max_retries + 1):
                try:
                    results = client.search(
                        search_text="*",
                        select="*",
                        top=page_size,
                        skip=skip,
                    )
                    page_docs = list(results)
                    break  # success
                except Exception:
                    if attempt < max_retries:
                        logger.warning(
                            "  Retry %d/%d for page at skip=%d",
                            attempt, max_retries, skip,
                        )
                        time.sleep(5 * attempt)
                    else:
                        logger.exception(
                            "  Failed to fetch page at skip=%d after %d attempts. "
                            "Stopping export for index '%s'.",
                            skip, max_retries, index_name,
                        )
                        logger.info(
                            "  Exported %d documents to %s (partial)",
                            doc_count, docs_path,
                        )
                        return

            if not page_docs:
                consecutive_empty += 1
                if consecutive_empty >= 2:
                    break
                skip += page_size
                continue

            consecutive_empty = 0
            for doc in page_docs:
                doc_dict = {
                    k: v for k, v in doc.items() if not k.startswith("@search.")
                }
                f.write(json.dumps(doc_dict, default=str) + "\n")
                doc_count += 1

            logger.info("  Exported %d documents so far...", doc_count)

            if len(page_docs) < page_size:
                break

            skip += page_size

    logger.info("  Exported %d documents to %s", doc_count, docs_path)


# ---------------------------------------------------------------------------
# Azure AI Search - Import
# ---------------------------------------------------------------------------

def import_search(export_dir: Path, endpoint: str) -> None:
    """Import search index schemas and documents into the target service."""
    from azure.search.documents.indexes import SearchIndexClient

    credential = _get_search_credential()

    index_client = SearchIndexClient(endpoint=endpoint, credential=credential)
    search_dir = export_dir / "search"

    if not search_dir.exists():
        logger.warning("No search export directory found at %s", search_dir)
        return

    schema_files = sorted(search_dir.glob("*_schema.json"))
    for schema_file in schema_files:
        index_name = (
             schema_file.stem[: -len("_schema")]
             if schema_file.stem.endswith("_schema")
             else schema_file.stem
         )
        logger.info("Importing search index: %s", index_name)
        _import_search_index_schema(index_client, schema_file, index_name)
        docs_file = search_dir / f"{index_name}_documents.jsonl"
        if docs_file.exists():
            _import_search_index_documents(
                endpoint, credential, index_name, docs_file
            )
        else:
            logger.warning("  No documents file found for index '%s'", index_name)


def _import_search_index_schema(
    index_client, schema_file: Path, index_name: str
) -> None:
    """Recreate the search index from the exported schema."""
    from azure.search.documents.indexes.models import SearchIndex

    try:
        schema = json.loads(schema_file.read_text(encoding="utf-8"))
        index = SearchIndex.from_dict(schema)
        index_client.create_or_update_index(index)
        logger.info("  Index '%s' created/updated.", index_name)
    except Exception:
        logger.exception("  Failed to create index '%s'", index_name)


def _import_search_index_documents(
    endpoint: str, credential, index_name: str, docs_file: Path
) -> None:
    """Upload documents to the target search index in batches."""
    from azure.search.documents import SearchClient

    client = SearchClient(
        endpoint=endpoint, index_name=index_name, credential=credential
    )
    batch_size = 100
    batch: list = []
    total = 0
    failed = 0

    with open(docs_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            doc = json.loads(line)
            batch.append(doc)
            if len(batch) >= batch_size:
                result = _upload_search_batch(client, batch, index_name)
                total += len(batch)
                failed += result
                batch = []

    if batch:
        result = _upload_search_batch(client, batch, index_name)
        total += len(batch)
        failed += result

    logger.info(
        "  Imported %d documents into '%s' (%d failures).",
        total,
        index_name,
        failed,
    )


def _upload_search_batch(client, batch: list, index_name: str) -> int:
    """Upload a single batch. Returns count of failed documents."""
    from azure.core.exceptions import HttpResponseError

    try:
        result = client.upload_documents(documents=batch)
        failures = sum(1 for r in result if not r.succeeded)
        if failures:
            logger.warning(
                "  %d documents failed in batch for index '%s'.",
                failures,
                index_name,
            )
        return failures
    except Exception:
        logger.exception(
            "  Batch upload failed for index '%s' (%d docs).",
            index_name,
            len(batch),
        )
        return len(batch)


# ---------------------------------------------------------------------------
# Cosmos DB (MongoDB API) - Export
# ---------------------------------------------------------------------------

def export_cosmos(export_dir: Path, conn_str: str, db_name: str, collection_names: list) -> None:
    """Export all documents from Cosmos DB MongoDB collections."""
    from pymongo import MongoClient

    cosmos_dir = export_dir / "cosmos"
    cosmos_dir.mkdir(parents=True, exist_ok=True)

    client = MongoClient(conn_str, tls=True, tlsAllowInvalidCertificates=False)
    try:
        db = client[db_name]
        for col_name in collection_names:
            logger.info("Exporting Cosmos collection: %s.%s", db_name, col_name)
            _export_collection(db, col_name, cosmos_dir)
    finally:
        client.close()


def _export_collection(db, collection_name: str, cosmos_dir: Path) -> None:
    """Export a single MongoDB collection to a JSONL file."""
    collection = db[collection_name]
    out_path = cosmos_dir / f"{collection_name}.jsonl"
    doc_count = 0

    try:
        with open(out_path, "w", encoding="utf-8") as f:
            for doc in collection.find():
                serializable = _bson_to_serializable(doc)
                f.write(json.dumps(serializable, default=str) + "\n")
                doc_count += 1
                if doc_count % 1000 == 0:
                    logger.info("  Exported %d documents so far...", doc_count)

        logger.info("  Exported %d documents to %s", doc_count, out_path)

        # Write a checksum sidecar for integrity verification
        _write_checksum(out_path, doc_count)
    except Exception as exc:
        logger.exception(
            "  Failed to export collection '%s'", collection_name
        )
        raise

def _bson_to_serializable(doc: dict) -> dict:
    """Recursively convert BSON types to JSON-serializable types."""
    import uuid
    from datetime import datetime

    from bson import Binary, ObjectId

    result = {}
    for key, value in doc.items():
        if isinstance(value, ObjectId):
            result[key] = str(value)
        elif isinstance(value, Binary):
            try:
                result[key] = str(uuid.UUID(bytes=bytes(value)))
            except (ValueError, AttributeError):
                result[key] = value.hex()
        elif isinstance(value, datetime):
            result[key] = value.isoformat()
        elif isinstance(value, dict):
            result[key] = _bson_to_serializable(value)
        elif isinstance(value, list):
            result[key] = [
                _bson_to_serializable(v)
                if isinstance(v, dict)
                else str(v)
                if isinstance(v, ObjectId)
                else v
                for v in value
            ]
        else:
            result[key] = value
    return result


def _write_checksum(file_path: Path, doc_count: int) -> None:
    """Write a sidecar checksum file for integrity verification."""
    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256.update(chunk)

    checksum_path = file_path.with_suffix(".checksum")
    checksum_data = {
        "file": file_path.name,
        "sha256": sha256.hexdigest(),
        "document_count": doc_count,
        "exported_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    checksum_path.write_text(
        json.dumps(checksum_data, indent=2), encoding="utf-8"
    )


# ---------------------------------------------------------------------------
# Cosmos DB (MongoDB API) - Import
# ---------------------------------------------------------------------------

def import_cosmos(export_dir: Path, conn_str: str, db_name: str) -> None:
    """Import documents into Cosmos DB MongoDB collections."""
    from pymongo import MongoClient

    cosmos_dir = export_dir / "cosmos"
    if not cosmos_dir.exists():
        logger.warning("No Cosmos export directory found at %s", cosmos_dir)
        return

    client = MongoClient(conn_str, tls=True, tlsAllowInvalidCertificates=False)
    try:
        db = client[db_name]
        for jsonl_file in sorted(cosmos_dir.glob("*.jsonl")):
            col_name = jsonl_file.stem
            logger.info("Importing Cosmos collection: %s.%s", db_name, col_name)
            _verify_checksum(jsonl_file)
            _import_collection(db, col_name, jsonl_file)
    finally:
        client.close()


def _verify_checksum(jsonl_file: Path) -> None:
    """Verify file integrity before import using the sidecar checksum."""
    checksum_path = jsonl_file.with_suffix(".checksum")
    if not checksum_path.exists():
        logger.warning(
            "  No checksum file found for %s - skipping verification.",
            jsonl_file.name,
        )
        return

    expected = json.loads(checksum_path.read_text(encoding="utf-8"))
    sha256 = hashlib.sha256()
    with open(jsonl_file, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256.update(chunk)

    actual_hash = sha256.hexdigest()
    if actual_hash != expected["sha256"]:
        logger.error(
            "  CHECKSUM MISMATCH for %s! Expected %s, got %s. "
            "Aborting import for this collection.",
            jsonl_file.name,
            expected["sha256"],
            actual_hash,
        )
        raise ValueError(f"Checksum mismatch for {jsonl_file.name}")

    logger.info(
        "  Checksum verified for %s (%d documents).",
        jsonl_file.name,
        expected["document_count"],
    )


def _import_collection(db, collection_name: str, jsonl_file: Path) -> None:
    """Import documents into a single MongoDB collection using upserts."""
    from bson import ObjectId
    from pymongo import ReplaceOne

    collection = db[collection_name]
    batch_size = 100
    batch: list = []
    total = 0
    failed = 0

    with open(jsonl_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            doc = json.loads(line)

            # Restore _id as ObjectId if it was serialized as a string
            if "_id" in doc and isinstance(doc["_id"], str):
                try:
                    doc["_id"] = ObjectId(doc["_id"])
                except Exception:
                    pass  # Keep as string if not a valid ObjectId

            # Use upsert to make the operation idempotent
            filter_key = doc.get("_id", doc.get("id"))
            batch.append(ReplaceOne({"_id": filter_key}, doc, upsert=True))

            if len(batch) >= batch_size:
                result = _write_cosmos_batch(collection, batch, collection_name)
                total += len(batch)
                failed += result
                batch = []

    if batch:
        result = _write_cosmos_batch(collection, batch, collection_name)
        total += len(batch)
        failed += result

    logger.info(
        "  Imported %d documents into '%s' (%d failures).",
        total,
        collection_name,
        failed,
    )


def _write_cosmos_batch(collection, batch: list, collection_name: str) -> int:
    """Execute a batch of upsert operations. Returns count of failures."""
    try:
        collection.bulk_write(batch, ordered=False)
        return 0
    except Exception:
        logger.exception(
            "  Batch write failed for collection '%s' (%d ops).",
            collection_name,
            len(batch),
        )
        return len(batch)


# ---------------------------------------------------------------------------
# Azure Blob Storage - Export
# ---------------------------------------------------------------------------

def export_blob_storage(export_dir: Path, account_name: str) -> None:
    """Export all containers and blobs from an Azure Storage account."""
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import BlobServiceClient

    account_url = f"https://{account_name}.blob.core.windows.net"
    credential = DefaultAzureCredential()
    blob_service = BlobServiceClient(
        account_url=account_url,
        credential=credential,
        connection_timeout=60,
        read_timeout=300,
        max_single_get_size=32 * 1024 * 1024,
        max_chunk_get_size=8 * 1024 * 1024,
    )

    blob_dir = export_dir / "blobstorage"
    blob_dir.mkdir(parents=True, exist_ok=True)

    containers = list(blob_service.list_containers())
    if not containers:
        logger.warning("No containers found in storage account '%s'.", account_name)
        return

    logger.info(
        "Containers to export from '%s': %s",
        account_name,
        [c["name"] for c in containers],
    )

    for container_info in containers:
        container_name = container_info["name"]
        logger.info("Exporting container: %s", container_name)
        _export_container(blob_service, container_name, blob_dir)


def _export_container(
    blob_service, container_name: str, blob_dir: Path
) -> None:
    """Download PDF and JSON blobs from a single container."""
    ALLOWED_EXTENSIONS = (".pdf", ".json")

    container_client = blob_service.get_container_client(container_name)
    container_dir = blob_dir / container_name
    _long_path(container_dir).mkdir(parents=True, exist_ok=True)

    # Collect blob names and content types to preserve metadata
    logger.info("  Listing blobs in container '%s'...", container_name)
    all_blobs = list(container_client.list_blobs(include=["metadata"]))
    blob_list = [b for b in all_blobs if b.name.lower().endswith(ALLOWED_EXTENSIONS)]
    logger.info("  Found %d blobs total, %d PDF/JSON files to export.", len(all_blobs), len(blob_list))

    content_type_map: dict = {}
    blob_count = 0
    failed = 0
    max_retries = 3

    for blob in blob_list:
        blob_name = blob.name
        blob_path = _long_path(container_dir / blob_name)

        # Capture content type from blob properties
        ct = blob.content_settings.content_type if blob.content_settings else None
        if ct:
            content_type_map[blob_name] = ct

        for attempt in range(1, max_retries + 1):
            try:
                blob_path.parent.mkdir(parents=True, exist_ok=True)

                blob_client = container_client.get_blob_client(blob_name)
                with open(blob_path, "wb") as f:
                    stream = blob_client.download_blob()
                    for chunk in stream.chunks():
                        f.write(chunk)

                blob_count += 1
                if blob_count % 50 == 0:
                    logger.info("  Exported %d / %d blobs...", blob_count, len(blob_list))
                break  # success
            except Exception:
                if attempt < max_retries:
                    logger.warning(
                        "  Retry %d/%d for blob '%s'", attempt, max_retries, blob_name
                    )
                    time.sleep(2 * attempt)
                else:
                    logger.exception("  Failed to export blob '%s' after %d attempts", blob_name, max_retries)
                    failed += 1

    # Save content-type metadata sidecar so import can restore it
    if content_type_map:
        meta_path = _long_path(container_dir / "__blob_metadata__.json")
        meta_path.write_text(json.dumps(content_type_map, indent=2), encoding="utf-8")
        logger.info("  Saved content-type metadata for %d blobs.", len(content_type_map))

    logger.info(
        "  Exported %d blobs from container '%s' (%d failures).",
        blob_count,
        container_name,
        failed,
    )


# ---------------------------------------------------------------------------
# Azure Blob Storage - Import
# ---------------------------------------------------------------------------

def import_blob_storage(export_dir: Path, account_name: str) -> None:
    """Import containers and blobs into an Azure Storage account."""
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import BlobServiceClient

    account_url = f"https://{account_name}.blob.core.windows.net"
    credential = DefaultAzureCredential()
    blob_service = BlobServiceClient(
        account_url=account_url,
        credential=credential,
        connection_timeout=60,
        read_timeout=600,
    )

    blob_dir = export_dir / "blobstorage"
    if not blob_dir.exists():
        logger.warning("No blob export directory found at %s", blob_dir)
        return

    # Each subdirectory in blob_dir is a container
    container_dirs = [d for d in sorted(blob_dir.iterdir()) if d.is_dir()]
    if not container_dirs:
        logger.warning("No container directories found in %s", blob_dir)
        return

    for container_dir in container_dirs:
        container_name = container_dir.name
        logger.info("Importing container: %s", container_name)
        _import_container(blob_service, container_name, container_dir)


def _import_container(
    blob_service, container_name: str, container_dir: Path
) -> None:
    """Upload all files from a local directory into a blob container."""
    import mimetypes
    from azure.storage.blob import ContentSettings

    # Create container if it doesn't exist
    container_client = blob_service.get_container_client(container_name)
    try:
        container_client.create_container()
        logger.info("  Container '%s' created.", container_name)
    except Exception:
        # Container already exists
        logger.info("  Container '%s' already exists.", container_name)

    # Use _long_path for directory iteration to find files beyond
    # Windows 260-char MAX_PATH limit.
    long_dir = _long_path(container_dir)

    # Load content-type metadata sidecar if available
    meta_path = long_dir / "__blob_metadata__.json"
    content_type_map: dict = {}
    if meta_path.exists():
        content_type_map = json.loads(meta_path.read_text(encoding="utf-8"))
        logger.info("  Loaded content-type metadata for %d blobs.", len(content_type_map))

    files_to_upload = [
        f for f in long_dir.rglob("*")
        if f.is_file() and f.name != "__blob_metadata__.json"
    ]
    logger.info("  Found %d files to upload.", len(files_to_upload))

    blob_count = 0
    failed = 0
    max_retries = 3
    for file_path in files_to_upload:
        # Preserve the blob name (relative path within the container dir)
        blob_name = file_path.relative_to(long_dir).as_posix()

        # Determine content type: prefer exported metadata, fall back to guess
        ct = content_type_map.get(blob_name)
        if not ct:
            ct, _ = mimetypes.guess_type(blob_name)
        content_settings = ContentSettings(content_type=ct) if ct else None

        for attempt in range(1, max_retries + 1):
            try:
                blob_client = container_client.get_blob_client(blob_name)
                with open(file_path, "rb") as f:
                    blob_client.upload_blob(
                        f, overwrite=True, content_settings=content_settings
                    )
                blob_count += 1
                if blob_count % 100 == 0:
                    logger.info("  Uploaded %d / %d blobs...", blob_count, len(files_to_upload))
                break  # success
            except Exception:
                if attempt < max_retries:
                    logger.warning(
                        "  Retry %d/%d for blob '%s'", attempt, max_retries, blob_name
                    )
                    time.sleep(3 * attempt)
                else:
                    logger.exception(
                        "  Failed to upload blob '%s' after %d attempts", blob_name, max_retries
                    )
                    failed += 1

    logger.info(
        "  Imported %d blobs into container '%s' (%d failures).",
        blob_count,
        container_name,
        failed,
    )


# ---------------------------------------------------------------------------
# CLI Entry Point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description=(
            "DKM Data Migration - Export/Import Azure AI Search, "
            "Cosmos DB & Blob Storage data between resource groups."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "action",
        choices=["export", "import", "export-import"],
        help="Action to perform: export, import, or export-import (full migration).",
    )
    parser.add_argument(
        "--search-only",
        action="store_true",
        help="Only migrate Azure Search data (skip Cosmos DB and Blob Storage).",
    )
    parser.add_argument(
        "--cosmos-only",
        action="store_true",
        help="Only migrate Cosmos DB data (skip Azure Search and Blob Storage).",
    )
    parser.add_argument(
        "--blob-only",
        action="store_true",
        help="Only migrate Blob Storage data (skip Azure Search and Cosmos DB).",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging.",
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    export_dir = get_export_dir()

    # Determine which services to migrate
    only_flags = [args.search_only, args.cosmos_only, args.blob_only]
    if sum(only_flags) > 1:
        logger.error("Only one of --search-only, --cosmos-only, --blob-only can be specified.")
        sys.exit(1)

    migrate_search = not args.cosmos_only and not args.blob_only
    migrate_cosmos = not args.search_only and not args.blob_only
    migrate_blob = not args.search_only and not args.cosmos_only

    # --- Collect all required inputs upfront ---
    source_search_ep = None
    target_search_ep = None
    source_cosmos_conn = None
    target_cosmos_conn = None
    cosmos_db_name = None
    cosmos_collections = None
    source_blob_account = None
    target_blob_account = None

    if migrate_search:
        if args.action in ("export", "export-import"):
            source_search_ep = _prompt("Enter SOURCE Search Endpoint (e.g. https://<name>.search.windows.net): ")
        if args.action in ("import", "export-import"):
            target_search_ep = _prompt("Enter TARGET Search Endpoint (e.g. https://<name>.search.windows.net): ")

    if migrate_cosmos:
        cosmos_db_name = "DPS"
        cosmos_collections = ["ChatHistory", "Documents"]
        if args.action in ("export", "export-import"):
            source_cosmos_conn = _prompt("Enter SOURCE Cosmos DB connection string: ")
        if args.action in ("import", "export-import"):
            target_cosmos_conn = _prompt("Enter TARGET Cosmos DB connection string: ")

    if migrate_blob:
        if args.action in ("export", "export-import"):
            source_blob_account = _prompt("Enter SOURCE Storage Account name: ")
        if args.action in ("import", "export-import"):
            target_blob_account = _prompt("Enter TARGET Storage Account name: ")

    # --- Azure login & RBAC role setup ---
    needs_azure_login = migrate_search or migrate_blob
    temp_role_assignments: list = []
    subscription_id = None
    principal_id = None

    if needs_azure_login:
        _check_azure_login()

        subscription_id = _prompt("Enter your Azure Subscription ID: ")
        principal_id = _get_signed_in_user_id()
        logger.info("Signed-in user principal ID: %s", principal_id)

    if migrate_search:
        if source_search_ep:
            temp_role_assignments.extend(
                _ensure_search_roles(source_search_ep, "source", subscription_id, principal_id)
            )
        if target_search_ep:
            temp_role_assignments.extend(
                _ensure_search_roles(target_search_ep, "target", subscription_id, principal_id)
            )

    if migrate_blob:
        if source_blob_account:
            temp_role_assignments.extend(
                _ensure_blob_roles(source_blob_account, "source", subscription_id, principal_id)
            )
        if target_blob_account:
            temp_role_assignments.extend(
                _ensure_blob_roles(target_blob_account, "target", subscription_id, principal_id)
            )

    start_time = time.time()
    try:
        if args.action in ("export", "export-import"):
            logger.info("=== EXPORT PHASE ===")
            if migrate_search:
                export_search(export_dir, source_search_ep)
            if migrate_cosmos:
                export_cosmos(export_dir, source_cosmos_conn, cosmos_db_name, cosmos_collections)
            if migrate_blob:
                export_blob_storage(export_dir, source_blob_account)
            logger.info("=== EXPORT COMPLETE ===")

        if args.action in ("import", "export-import"):
            logger.info("=== IMPORT PHASE ===")
            if migrate_search:
                import_search(export_dir, target_search_ep)
            if migrate_cosmos:
                import_cosmos(export_dir, target_cosmos_conn, cosmos_db_name)
            if migrate_blob:
                import_blob_storage(export_dir, target_blob_account)
            logger.info("=== IMPORT COMPLETE ===")

        logger.info("Migration finished successfully.")
    finally:
        _revoke_roles(temp_role_assignments)
        elapsed = time.time() - start_time
        logger.info("Total execution time: %s", _format_duration(elapsed))


if __name__ == "__main__":
    main()
