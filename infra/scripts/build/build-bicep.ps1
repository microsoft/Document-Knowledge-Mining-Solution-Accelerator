# Compile all Bicep entrypoints to ARM JSON for inspection / what-if previews.
#
# Replaces the legacy `infra/build-main.json.sh` (which only built the monolith).
# After the infra restructure (WI #45205) there are two parallel flavors:
#   * infra/bicep/main.bicep — raw Microsoft.* resources
#   * infra/avm/main.bicep   — Azure Verified Modules wrappers
# The legacy `infra/main.bicep` is also built while it remains in the tree.

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraDir  = Resolve-Path (Join-Path $ScriptDir '..\..')

function Build-Bicep([string]$RelativePath) {
    $full = Join-Path $InfraDir $RelativePath
    if (Test-Path $full) {
        Write-Host "==> az bicep build -f $RelativePath"
        Push-Location $InfraDir
        try { az bicep build -f $RelativePath } finally { Pop-Location }
    } else {
        Write-Host "--- skip $RelativePath (not present)"
    }
}

Build-Bicep 'bicep/main.bicep'
Build-Bicep 'avm/main.bicep'
Build-Bicep 'main.bicep'

Write-Host 'OK'
