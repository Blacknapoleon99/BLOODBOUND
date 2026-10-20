# Tool integrations — Windows 11 + Claude Code + Codex

## Rules

- Read `prompts/AUTONOMOUS_BOOTSTRAP.md` first for installation order and user authorization.
- Verify installed versions and source trust. Use user/project-scoped integrations; back up and **merge** existing config rather than replacing unrelated MCP settings.
- Prefer CLI/tool APIs to GUI automation for repeatable changes. Browser automation = Playwright; Windows desktop automation = separate powerful third-party tools.
- For each integration record `absent`, `installed`, `configured`, `connected`, `smoke-tested` or `blocked` in `docs/ENVIRONMENT_REPORT.md`.
- An MCP server can execute arbitrary local operations. Review its publisher, source, active maintenance and permissions before enabling. The user must approve high-privilege desktop control or a paid API.

## Base installations

Check `where.exe godot`, `where.exe blender`, `winget list`, Node, Python, Git, uv/uvx. Install **missing** components only. Suggested official Windows packages (confirm IDs and versions with `winget show`/`winget search` first):

```powershell
winget search GodotEngine.GodotEngine
winget search BlenderFoundation.Blender
winget search OpenJS.NodeJS.LTS
winget search Git.Git
winget search Python.Python.3.12
```

Official Godot Windows download: https://godotengine.org/download/windows/ (4.7.2 stable as of package authoring). Use **standard** GDScript build, not .NET unless decided separately. After install check editor executable and its version; add PATH only as appropriate. Add export templates for the installed engine version using Godot's editor, document success. Blender: https://www.blender.org/download/ . Node.js LTS: https://nodejs.org/ . Git: https://git-scm.com/ . Python: https://www.python.org/ . uv: https://docs.astral.sh/uv/getting-started/installation/ .

Typical checks (resolve `godot` command/path first):

```powershell
python tools/doctor.py
python tools/validate_template.py
godot --headless --path . --import
godot --headless --path . --quit-after 30
```

Open the editor and execute actual keyboard gameplay tests too; headless checks are not visual verification. Web export uses Godot Compatibility/WebGL2 and requires a functioning export preset/templates. See https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html .

## Godot Forge MCP (project editor integration)

A community solution with an editor addon and MCP server: https://github.com/Tann2019/godot-mcp-server . Review code/maintenance before installing. It documents Godot 4.4+ and recommends 4.7.

```powershell
# from project root; review modifications to addons/, project.godot, and .mcp.json
npx -y godot-forge-mcp@latest install
npx -y godot-forge-mcp@latest doctor
```

Install may write `.mcp.json`: **merge** existing integrations and back up before overwriting. Claude Code should trust the project and approve this MCP; check with `/mcp` and perform one real Godot inspection and playtest command. Pin a tested release after installation. Codex users can configure equivalent stdio server per upstream docs.

## Microsoft Playwright MCP — browser use

Official source: https://github.com/microsoft/playwright-mcp . Requires Node.js (current docs recommend >=20 for setup). Claude Code example (CLI run from a separate terminal or shell execution, not typed as natural language):

```powershell
claude mcp add --scope project playwright -- npx @playwright/mcp@latest
```

Then restart/reload MCP if required; run `/mcp`, navigate to https://demo.playwright.dev/todomvc, verify a snapshot. If no browser is installed, follow Playwright's current browser installer docs; common fallback `npx playwright install chromium`. Use Playwright to test browser-exported Godot games and take screenshots. It does **not** manipulate arbitrary Windows desktop UI.

## Blender + Blender MCP

Community source: https://github.com/ahujasid/blender-mcp . Needs Blender >=3, Python and `uvx` from official uv installation. Once source reviewed:

```powershell
claude mcp add --scope project blender -- uvx blender-mcp
uvx blender-mcp install-addon
```

Enable `Interface: MCP for Blender` in Blender Preferences → Add-ons. Open 3D viewport sidebar (`N`) → MCP for Blender → Start server. The add-on runs code inside Blender: do not load untrusted .blend Python scripts or execute arbitrary online code. Only allow Blender access to current game's art directory. Smoke-test a read-only scene object listing and an original small cube export to `assets/processed/`. Record actual GLB import validation in Godot.

## Tripo3D official CLI (asset generation, paid calls gated)

Official agent help: https://www.tripo3d.ai/help/api-plugins/ai-agenttripo-api
Official developer docs: https://developers.tripo3d.ai/en/docs/quick-start

```powershell
npm install -g tripo-cli
tripo --help
```

Verify exact binary/commands from `tripo --help`; prompt for user's sign-in or securely entered `TRIPO_API_KEY` only if needed, without echoing it into project source/logs. **Never generate models before asking** because API credits/billing may apply. Official v3 flow: `POST https://openapi.tripo3d.ai/v3/generation/text-to-model`, poll `GET https://openapi.tripo3d.ai/v3/tasks/{task_id}`, download returned GLB immediately. Do not mix old v2 endpoints. File pipeline: `assets/incoming/` → Blender optimization/rigging → `assets/processed/` → Godot import, plus manifest provenance and license record.

## Windows computer-use / GUI control (optional, high-power)

Example community project for Windows Claude Code: https://github.com/ryanportfolio/winuse-mcp — **third-party, not an official Anthropic tool**. Its documented pinned install is:

```powershell
# ONLY after source review and approval for local desktop control
claude mcp add --scope local winuse -- uvx --from git+https://github.com/ryanportfolio/winuse-mcp@v0.2.0 winuse-mcp
```

Verify publisher/release tag, Python requirements (>=3.12), dependencies and emergency-stop behavior. It can read the screen and control mouse/keyboard. Do not install and automatically grant full access without discussing consequences. Run under normal user, no elevation, close unrelated sensitive windows, don't expose network listeners, limit calls to Godot/Blender/test browser, and enable manual approval on potentially risky actions. Smoke-test only a screenshot of the game window before using interactive controls. Windows user might need to explicitly approve MCP use. Avoid naming the server `computer-use`, which is reserved in Claude Code.

## Jev AI / other animation and media tools

`Jev AI` is not uniquely identified/verified. Inspect currently installed capabilities and ask user for the exact provider link if necessary. Do not invent an API endpoint, model, MCP or subscription. Other image/animation/audio providers can be added later, after verifying cost, rights, data privacy, supported formats and actual need. Procedural placeholders and Blender are enough for first gameplay milestone.

## Config health / lifecycle

Use `claude mcp list`, `claude mcp get <name>`, and interactive `/mcp`. A successful `claude mcp add` **only means config was written**, not that the integration connected. Project `.mcp.json` requires user trust/approval before launching servers; the user should review changes and accept only known entries. See https://code.claude.com/docs/en/mcp . Restart Claude Code if tools are not visible; save a checkpoint first. Keep project `.mcp.json` from embedding secrets or machine-specific private paths. Pin known-working versions and update intentionally.

## Agent work division and credential policy

Dedicated subagents: project setup/MCP audit; Godot validation; gameplay; combat; boss architecture; asset ingestion; QA. Project manager assigns non-overlapping file ownership and integrates changes. Only write API keys into user-level secure env/credential manager. Do not add to git, `.mcp.json`, GDScript or screenshots.
