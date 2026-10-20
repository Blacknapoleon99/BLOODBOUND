# AGENTS.md — project contract (Codex and other coding agents)

This is a Godot 4.7 GDScript project. Read `MASTER_PROMPT.md` for full scope; begin with `prompts/AUTONOMOUS_BOOTSTRAP.md` on a new Windows installation, then `prompts/FIRST_RUN.md`. The shipping game must be original (inspired by—not copied from—other titles).

## Execution contract

- **Make real changes and execute tests.** Documentation alone is not a deliverable.
- The included greybox is only a bootstrap, not evidence that future systems already work.
- Inspect the installed Godot version and project before changing code. Use GDScript and the Compatibility renderer until a reviewed change.
- Keep the project bootable; favor small vertical slices and frequent commits after verified milestones.
- Don't invent MCP tools, plugin names, AI asset models, API endpoints, or success states. Discover and verify capabilities first.
- No paid generation, external upload, social posting, publishing, or vendor account modification without explicit user consent.
- Protect credentials: local environment variables, ignored `.env`; never echo secret values in logs or commit them.
- External assets must have provenance/licensing notes; generated models enter `assets/incoming`, then cleaned assets go to `assets/processed`.
- Run `python tools/validate_template.py` and then actual Godot headless import/boot (when installed); report results and limitations. Runtime boot ≠ gameplay verification.
- Do not silently break 2.5D controls while adding full-3D arenas.
- Work from `docs/ROADMAP.md` and `docs/ACCEPTANCE.md`. Mark complete only with evidence in `docs/TEST_RESULTS.md`.
- Never mark a task complete because it was mentioned in a prompt or stubbed in code.

## Architecture contracts

- Player movement, combat, health, damage, enemy AI, boss phases, cards, world events, cameras, UI, and asset-swapping stay independent.
- World coordinates: Godot Y up, X is side-scroll, Z is depth. Side-scrolling movement locked to Z=0; full 3D allows X/Z movement.
- Godot 3D scenes are the source of truth; no fake 2D-only game substitutes.
- Cards are real-time abilities during boss combat, not a separate turn-based minigame.
- The first boss attacks the player from depth and has readable telegraphs/real hit detection.
- Use data-driven Resources for cards/attack definitions, signals for events, and testable nodes.
- Native Windows experience first; browser Compatibility/WebGL2 path must be smoke-tested early, not guaranteed.

## Work updates

For each work cycle: (1) state current milestone, (2) list changed files, (3) report commands and observed results, (4) identify blockers, (5) choose next action. Document a durable checkpoint in `docs/PROGRESS.md`.
