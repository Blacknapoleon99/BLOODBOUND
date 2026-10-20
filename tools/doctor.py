#!/usr/bin/env python3
"""Non-mutating local dependency check. Never prints secrets."""
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
print(f"Bloodbound dependency doctor | platform={platform.platform()}")
print(f"Project root: {ROOT}")
print(f"Python: {sys.version.split()[0]}")
for name in ("godot", "godot4", "Godot_v4.7-stable_win64_console.exe", "blender", "claude", "codex", "uvx", "git"):
    found = shutil.which(name)
    print(f"{name:38} {'FOUND: ' + found if found else 'NOT FOUND on PATH'}")
print(f"TRIPO_API_KEY configured: {'yes' if os.getenv('TRIPO_API_KEY') else 'no'} (value hidden)")

for name in ("godot", "godot4", "Godot_v4.7-stable_win64_console.exe"):
    candidate = shutil.which(name)
    if candidate:
        try:
            result = subprocess.run([candidate, "--version"], timeout=10, text=True, capture_output=True)
            print(f"Engine version: {(result.stdout or result.stderr).strip()[:150]} (exit {result.returncode})")
        except Exception as exc:
            print(f"Could not invoke version check: {type(exc).__name__}: {exc}")
        break
print("Note: this doctor checks availability only. Runtime game tests must be run separately.")
