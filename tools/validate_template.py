#!/usr/bin/env python3
"""Check source ZIP/template paths and structure; cannot parse or run GDScript."""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
required = [
    "project.godot", "README.md", "AGENTS.md", "CLAUDE.md", "MASTER_PROMPT.md",
    "prompts/FIRST_RUN.md", "docs/ROADMAP.md", "docs/ACCEPTANCE.md", "docs/TEST_RESULTS.md",
    "docs/TOOL_INTEGRATIONS.md", "docs/ASSET_PIPELINE.md", "scenes/main.tscn", "scenes/player.tscn",
    "scripts/main.gd", "scripts/player.gd", "assets/manifests/assets.json"
]
failures = []
for name in required:
    if not (ROOT / name).is_file():
        failures.append(f"Missing: {name}")

for path in list(ROOT.rglob("*.tscn")) + list(ROOT.rglob("*.gd")) + [ROOT / "project.godot"]:
    if not path.is_file():
        continue
    text = path.read_text(encoding="utf-8")
    for match in re.finditer(r'res://([\w./-]+)', text):
        target = ROOT / match.group(1)
        if not target.exists():
            failures.append(f"Missing res:// reference in {path.relative_to(ROOT)}: {match.group(0)}")
    if path.suffix == ".tscn" and "[gd_scene" not in text:
        failures.append(f"Missing scene header: {path.relative_to(ROOT)}")

try:
    manifest = json.loads((ROOT / "assets/manifests/assets.json").read_text(encoding="utf-8"))
    assert isinstance(manifest.get("assets"), list)
except Exception as exc:
    failures.append(f"Bad asset manifest: {exc}")

if failures:
    print("STATIC TEMPLATE VALIDATION FAILED")
    print("\n".join(f"- {f}" for f in failures))
    sys.exit(1)
print(f"Static file and resource-path validation passed: {len(required)} required files present.")
print("This does not mean GDScript compiled or the game was playtested. Run Godot 4.7 next.")
