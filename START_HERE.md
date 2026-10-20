# Start here — Autonomous Windows 11 setup

This starter supports autonomous setup by Claude Code. **Start with `prompts/AUTONOMOUS_BOOTSTRAP.md`, not `prompts/FIRST_RUN.md`, on a machine that needs tools installed.** The agent is instructed to audit the PC, install missing official/free tooling, connect/test reviewed MCPs, run and repair the existing Godot project, then begin gameplay work. Paid tools, credentials and unrestricted desktop control require your approval.

1. Extract the entire ZIP to a normal folder.
2. Open PowerShell in that folder and run `claude` (Claude Code already installed) or `codex`.
3. Tell Claude: **"Read `prompts/AUTONOMOUS_BOOTSTRAP.md` and execute it end-to-end. Install missing official tools on Windows, set up and verify the Godot/Blender/Playwright MCPs, ask for my approval where needed, launch and test the existing starter, then continue into `prompts/FIRST_RUN.md`. Do not just give me instructions."**
4. After first setup, resume with `prompts/FIRST_RUN.md` and `docs/PROGRESS.md`.

If Claude Code itself is not installed/logged in, you must install and authenticate it manually first — it cannot run before its own initial setup. Godot, Blender, Playwright and associated MCPs can be installed by the running coding agent using available shell permissions.
