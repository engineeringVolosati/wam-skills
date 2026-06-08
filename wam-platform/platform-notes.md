# WAM platform — storage, persistence, and known limits

**Written:** 2026-06-08. Platform evolves — verify against current WAM docs
or test in a fresh session before relying on anything here. We may have missed
updates.

---

## Storage tiers

**`workspace/`** — persistent. Survives agent restarts, session reloads,
and container restarts. Backed up hourly via `backup_bundle.py` to a Windows
machine and to GitHub. This is the primary working directory. Store everything
that must survive here.

**`~/.local/`** — pip packages, node modules, compiled binaries. Survives
ordinary container restarts. Lost on a full container wipe (image rebuild).
After wipe: re-run `pip install --user <packages>`.

**`/tmp/`** — ephemeral. Cleared on every container restart. Use for
scratch files within a session only. Never store anything important here
that must survive beyond the current turn.

**WAM secret vault** (Cloudflare KV via MCP) — external to the container.
Survives any wipe. Use `superlisa_store_secret` / `superlisa_get_secret`.
The tunnel URL, API keys, OAuth tokens go here if they need to outlive
the container.

**`.secrets/.env`** — lives in `workspace/`, so it persists normally.
Also backed up to the Windows machine (not to GitHub). Use for tokens
that need to be readable by scripts without MCP.

---

## What the supervisor manages

`services/supervisor.py` starts and keeps alive:

- `scheduler` — one-shot and interval tasks created dynamically by the agent
- `ag_gateway` — HTTP bridge to ag-linux (Windows WSL2 machine)
- `lisa-cron` — wall-clock aligned cron jobs (binary in `lisa-cron/.bin/`)

The supervisor health-checks every 15s and restarts dead processes.
It does NOT manage most daemons — those are owned by `topic_loader.py`,
which calls `--ensure` on every user-prompt:

- `backup_daemon`
- `reminder_daemon`
- `dashboard_daemon`
- `lisa_core_issue_watcher`
- `merlin_relay_daemon`
- `silno_dom_monitor_daemon`
- `channel_scan_daemon`
- `scrap_daemon`
- `tunnel_monitor`

After a container restart, supervisor auto-starts its three services.
The topic_loader-managed daemons wake up on the first user message.

---

## Known platform limits (as of 2026-06-08)

**`superlisa_set_model` MCP tool** writes to read-only `/opt/superlisa/` —
broken. Workaround: `python3 scripts/set_model.py <model> --topic <chat_id> <thread_id>`.

**`CronCreate`** is session-only. Tasks are lost when the agent restarts.
Use `scripts/reminders.json` (reminder_daemon) or lisa-cron for durable
scheduled tasks. CronCreate is only safe for in-session polling loops
where losing the task on restart is acceptable.

**TranscriptAPI MCP** is not properly hoisted — `ListMcpResourcesTool` won't
show it. Call it via direct HTTP POST with SSE parsing, or use
`scripts/transcript_wrapper.py`.

**Video decoding** — no native video support. Use `scripts/video_frames.py`
to extract N frames as JPEG, then read frames with the Read tool.

**Image size** — images with any side > 1999px must be resized before
reading (context overflow risk). Use Pillow `thumbnail((1999, 1999))`.

**`gh` CLI + `GITHUB_TOKEN` env var** — if `GITHUB_TOKEN` is set in the
environment, `gh auth login --with-token` fails with a conflict error.
Use the GitHub REST API directly via `urllib` instead. Always prefer
`GITHUB_VOLOSATI_TOKEN` → `GH_TOKEN` → `GITHUB_TOKEN` in that order.

---

## What survives a container wipe

Survives (external storage):
- WAM secret vault (Cloudflare KV)
- GitHub repos (your code)
- Windows backup bundle (`C:\GIT\AGENTS\superlisa-backup\`)
- Telegram messages (in Telegram servers)

Does NOT survive without backup:
- `workspace/` contents — recovered via `restore_bundle.py`
- `volosati.session` (Telethon session) — requires re-auth or encrypted backup
- `~/.local/` pip packages — reinstall after restore
- Google OAuth `token.json` — recovered via `scripts/restore_google_token.py both`
  (uses refresh_token from vault)

Full recovery checklist: `useragents/REGISTRY.md` → Post-restore checklist.
