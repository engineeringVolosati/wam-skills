# "I want to connect to X" — how agents should handle it

When a user says "connect my agent to [service / device / platform]",
the agent must try to make it happen — not explain why it might be hard.

---

## Decision tree

```
User: "I want to connect to X"
  │
  ├─ Does X have a public API?
  │    └─ Yes → use urllib / requests / gh CLI / MCP tool directly.
  │             Check REGISTRY.md first — the tool may already exist.
  │
  ├─ Does X require login / OAuth?
  │    └─ Yes → try OAuth flow via google-agent or browser automation
  │             (agent-browser for sites with no API).
  │             Store token in WAM vault (superlisa_store_secret).
  │
  ├─ Does X require SSH or local network access?
  │    └─ Yes → route via ag_gateway (exec on ag-linux / Windows WSL2).
  │             Tailscale tunnel for LAN devices.
  │
  ├─ Does X require a browser with JS?
  │    └─ Yes → agent-browser (headless Chrome, see research/agent-browser.md).
  │
  └─ Is X physically impossible from the container? (e.g. USB, Bluetooth,
       hardware that requires a local binary we don't have, platform that
       actively blocks agent IPs?)
       └─ → File an issue (see below) + tell user to contact WAM support.
```

---

## Exhaust options before declaring impossible

Before giving up, try:
- Different API endpoints (v1 vs v2, REST vs GraphQL)
- `curl -s "https://r.jina.ai/<url>"` — strips JS/CSS, reveals API calls
- `agent-browser` to bypass bot-detection and capture auth cookies
- ag_gateway to run code on the user's local machine
- Cloudflare Worker as a CORS proxy if the service blocks cloud IPs

Only declare "not possible from the container" after you have actually tried
and hit a hard wall (IP block, hardware dependency, closed API with no workaround).

---

## When it's genuinely not possible

Do both of the following:

**1. File an issue in the relevant repo.**

If the blocker is a WAM platform limitation (missing MCP tool, missing binary,
network restriction), file in `volosati-team/lisa-core`:

```
Title: feat: support connecting to <X>
Body:
**Source:** <topic name> · chat_id <id> · thread_id <id>

User wants to connect their agent to <X>.
Blocker: <what exactly is missing — tool, permission, binary, network access>.
Workaround attempted: <what was tried>.
Proposed solution: <MCP tool / binary / tunnel / policy change>.
```

If the blocker is in a product repo, file there instead.

**2. Tell the user to contact WAM support.**

```
Прямо сейчас из контейнера подключиться к <X> не получается — <одна фраза причины>.
Я завела issue #N в lisa-core с описанием что нужно.
Для ускорения — напиши /support в @wamagentsbot, приложи ссылку на issue.
```

Do not leave the user with just "it's not possible." Always close the loop:
issue + support path.

**3. Set up a cron check for issue resolution.**

After filing, register a periodic job that polls the issue and notifies the
user when it closes. Use lisa-cron:

```toml
# lisa-cron.toml — add this job after filing issue #N
[[jobs]]
name        = "check-issue-N-resolved"
schedule    = "0 10 * * *"          # daily at 10:00
command     = "python3"
args        = ["/home/superlisa/workspace/scripts/check_issue_resolved.py",
               "--repo", "volosati-team/lisa-core",
               "--issue", "N",
               "--chat-id", "<chat_id>",
               "--thread-id", "<thread_id>"]
timeout_secs = 30
```

Minimal checker script pattern:

```python
#!/usr/bin/env python3
"""Poll a GitHub issue; notify via bot when closed."""
import sys, os, json, urllib.request, pathlib

REPO   = sys.argv[sys.argv.index("--repo") + 1]
ISSUE  = sys.argv[sys.argv.index("--issue") + 1]
CHAT   = int(sys.argv[sys.argv.index("--chat-id") + 1])
THREAD = int(sys.argv[sys.argv.index("--thread-id") + 1])

def _token():
    for k in ("GITHUB_VOLOSATI_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"):
        t = os.environ.get(k, "")
        if t: return t
    env = pathlib.Path("/home/superlisa/workspace/.secrets/.env")
    for line in env.read_text().splitlines():
        for k in ("GITHUB_VOLOSATI_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"):
            if line.strip().startswith(f"{k}="):
                t = line.split("=", 1)[1].strip()
                if t: return t

req = urllib.request.Request(
    f"https://api.github.com/repos/{REPO}/issues/{ISSUE}",
    headers={"Authorization": f"Bearer {_token()}", "Accept": "application/vnd.github+json"},
)
with urllib.request.urlopen(req, timeout=10) as r:
    issue = json.loads(r.read())

if issue["state"] != "closed":
    sys.exit(0)  # not yet — cron will retry tomorrow

# Closed — notify user and remove this job from lisa-cron
BOT_TOKEN = os.environ.get("BOT_TOKEN", "")
url = issue["html_url"]
text = f"✅ Issue #{ISSUE} закрыт — функция доступна.\n{url}"
payload = json.dumps({"chat_id": CHAT, "text": text, "message_thread_id": THREAD}).encode()
req2 = urllib.request.Request(
    f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
    data=payload, headers={"Content-Type": "application/json"},
)
urllib.request.urlopen(req2, timeout=10)

# Self-remove from lisa-cron so it doesn't run again
os.system(f"python3 /home/superlisa/workspace/scripts/lisa_cron_cli.py remove check-issue-{ISSUE}-resolved")
```

When the issue closes, the user gets a notification and the job removes itself.
Remove the job manually if the user loses interest:

```sh
python3 scripts/lisa_cron_cli.py remove check-issue-N-resolved
```

---

## Storing new connections

When a new connection is successfully set up:
- Token / API key → `superlisa_store_secret` (WAM vault) or `.secrets/.env`
- Re-auth procedure → document in `useragents/REGISTRY.md` under the relevant tool
- Connection details → note in `projects/<topic>/override.md` so the next session
  starts with context about the existing connection
