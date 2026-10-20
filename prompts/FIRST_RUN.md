# FIRST RUN — after initial environment bootstrap

**If this is the first session on a new computer, do `prompts/AUTONOMOUS_BOOTSTRAP.md` first.** That task installs Godot, tests MCP connections, starts the editor and then proceeds here. If bootstrap was already completed, read the saved environment and test reports and continue without duplicating installations.

You have been given an existing Godot 4.7-compatible project starter for **BLOODBOUND: The Hollow Covenant**.

1. Read `AGENTS.md`, `CLAUDE.md`, `MASTER_PROMPT.md`, `docs/ROADMAP.md`, `docs/ACCEPTANCE.md` and `docs/TOOL_INTEGRATIONS.md` first.
2. Inspect project sources and git status. Preserve the starter; do not replace it wholesale.
3. Run `python tools/doctor.py` and `python tools/validate_template.py`; use existing Godot 4.7.x stable, otherwise follow autonomous bootstrap to install it. Then perform headless import and boot, visible launch and gameplay verification; record actual outcomes.
4. Repair any current errors. Verify greybox A/D movement, Space jump, J attack, E arena mode, R restart and victory flow. A run without input is not sufficient gameplay proof.
5. Commit a safe verified baseline; update `docs/TEST_RESULTS.md`, `docs/PROGRESS.md`, and `docs/ROADMAP.md`.
6. Implement the next uncompleted M1 gameplay item: responsive platforming, checkpoints, player states and collision. Keep systems modular and browser-Compatible.
7. Delegate non-overlapping review and QA subtasks when available. Integrate and test changes.
8. Do not call paid generation APIs, access unrelated personal data, upload private assets, or publish without approval. If a tool is missing, fall back to CLI and placeholders rather than stall.

Do real development in files, report changed files, tested behaviors, remaining blockers and next milestone.
