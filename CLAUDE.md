# Claude Code entrypoint — BLOODBOUND

Follow the project-wide instructions in `AGENTS.md`, the complete design and implementation scope in `MASTER_PROMPT.md`, and the external integrations protocol in `docs/TOOL_INTEGRATIONS.md`.

**First action:** execute `prompts/AUTONOMOUS_BOOTSTRAP.md` on first Windows setup (or resume `prompts/FIRST_RUN.md` if installation is verified) instead of starting asset generation. Open the actual Godot project and verify its current behavior. Treat all checked boxes as incomplete unless runtime evidence exists in `docs/TEST_RESULTS.md`.

When subagents are available, assign bounded non-overlapping tasks using `.claude/agents/` role briefs, then integrate and validate their output. Do not assume an agent can edit files concurrently without conflict; assign separate file ownership. Keep main conversation focused on integration and release gates.

Do not autonomously run paid Tripo3D/Jev AI requests or transmit files to third parties. Ask for permission for each cost-bearing batch. Review third-party MCP implementations before installation, especially anything that can execute scripts in Blender or read the filesystem.
