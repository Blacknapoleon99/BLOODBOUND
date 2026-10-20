param([string]$Godot = "godot_console")
# Exports the Windows release, Windows QA (debug) and Web builds, then runs the in-game
# export probe (scripts/qa/export_probe.gd) against both Windows builds.
# The Web build is probed separately in a browser: serve build/web over HTTP and open
# index.html?export-probe (see docs/WEB_EXPORT.md).
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
New-Item -ItemType Directory -Force build/windows, build/windows-qa, build/web | Out-Null

Write-Host "=== Import ==="
& $Godot --headless --path . --import *> $null

foreach ($preset in @(
        @{ Name = "Windows Desktop"; Path = "build/windows/Bloodbound.exe"; Mode = "--export-release" },
        @{ Name = "Windows Desktop (QA)"; Path = "build/windows-qa/BloodboundQA.exe"; Mode = "--export-debug" },
        @{ Name = "Web"; Path = "build/web/index.html"; Mode = "--export-release" })) {
    Write-Host ("=== Export {0} ===" -f $preset.Name)
    & $Godot --headless --path . $preset.Mode $preset.Name $preset.Path *> $null
    if ($LASTEXITCODE -ne 0) { Write-Host "Export failed: $($preset.Name)"; exit $LASTEXITCODE }
}

Write-Host "=== Probe: QA build (console output) ==="
& ./build/windows-qa/BloodboundQA.console.exe --headless -- --export-probe
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== Probe: release build (exit code only; GUI subsystem has no console) ==="
$p = Start-Process ./build/windows/Bloodbound.exe -ArgumentList "--headless", "--", "--export-probe" -PassThru -Wait
Write-Host ("release probe exit code: {0}" -f $p.ExitCode)
exit $p.ExitCode
