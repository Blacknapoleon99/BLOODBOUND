param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
Write-Host "=== Static validation ==="
python tools/validate_template.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "=== Godot headless import ==="
& $Godot --headless --path . --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "=== Godot short headless boot ==="
& $Godot --headless --path . --quit-after 30
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Done. Visual/manual testing is still required (see docs/ACCEPTANCE.md)."
