# Read-only Windows developer-tool audit for BLOODBOUND.
# Does not install, change PATH, or read secrets.
$ErrorActionPreference = 'Continue'
Write-Output 'BLOODBOUND WINDOWS PREFLIGHT (READ ONLY)'
Write-Output ('Time: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
Write-Output ('OS: ' + [System.Environment]::OSVersion.VersionString)
$commands = @('winget','git','node','npm','npx','python','py','uv','uvx','godot','godot4','blender','claude','codex')
foreach ($name in $commands) {
    $entry = Get-Command $name -ErrorAction SilentlyContinue
    if ($entry) {
        Write-Output ("[FOUND] {0}: {1}" -f $name, $entry.Source)
        if ($name -in @('git','node','npm','python','py','uv','uvx','godot','godot4','blender','claude','codex')) {
            try {
                $version = (& $entry.Source --version 2>&1 | Select-Object -First 2) -join ' '
                if ($version) { Write-Output ("         {0}" -f $version) }
            } catch { Write-Output '         [version check unavailable]' }
        }
    } else { Write-Output ("[MISSING IN PATH] {0}" -f $name) }
}
Write-Output 'Godot and Blender may be installed outside PATH; inspect installed apps and executable directories before concluding absent.'
Write-Output 'Do not include user secrets or token values in the saved report.'
