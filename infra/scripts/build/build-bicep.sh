#!/usr/bin/env bash
# Compile all Bicep entrypoints to ARM JSON for inspection / what-if previews.
#
# Replaces the legacy `infra/build-main.json.sh` (which only built the monolith).
# After the infra restructure (WI #45205) there are two parallel flavors:
#   * infra/bicep/main.bicep — raw Microsoft.* resources
#   * infra/avm/main.bicep   — Azure Verified Modules wrappers
# The legacy `infra/main.bicep` is also built while it remains in the tree.
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFRA_DIR="$( cd "${SCRIPT_DIR}/../.." && pwd )"

build() {
  local file="$1"
  if [[ -f "${INFRA_DIR}/${file}" ]]; then
    echo "==> az bicep build -f ${file}"
    ( cd "${INFRA_DIR}" && az bicep build -f "${file}" )
  else
    echo "--- skip ${file} (not present)"
  fi
}

build "bicep/main.bicep"
build "avm/main.bicep"
build "main.bicep"

echo "OK"
