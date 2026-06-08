# wam-skills

Practical guides and tools for WAM agent users. Each guide is written for humans
AND their AI agents — meaning your agent can read these files directly to perform
the setup for you.

No corporate filler. No "Introduction" sections that restate the title. Just steps.

---

## Directory structure

```
wam-skills/
├── vpn/
│   ├── README.md                    # VPN key aggregation + subscription URLs
│   └── karing-throne-setup.md       # Add subscription URLs to Karing / Throne
│
├── cloudflare/
│   └── worker-setup.md              # Deploy Workers via wrangler + GitHub Actions, KV storage
│
├── voice/
│   ├── deepgram-ipa.md              # Deepgram IPA: BYOK, $200 free credits, cost math
│   └── voice-cloning.md             # Nano voice cloning (placeholder, coming soon)
│
├── networking/
│   └── tailscale-tunnel.md          # Connect agent (Docker, no root) to your computer
│
├── monitoring/
│   ├── session-watchdog.md          # Detect hung agent sessions, alert via Telegram
│   └── findings-board-template.md   # Shared research board for parallel agent teams
│
├── research/
│   ├── pwc_search.sh                # PapersWithCode search CLI
│   ├── jina-reader.md               # Jina r.jina.ai — clean page text without JS/CSS
│   └── agent-browser.md             # agent-browser: headless Chrome for auth/JS sites
│
├── github/
│   └── agent-github-guide.md        # Read files, search repos, create issues/PRs via API
│
├── chat-management/
│   └── topic-override-pattern.md    # How topic overrides work in WAM agents
│
├── scheduling/
│   └── lisa-cron-quickstart.md      # lisa-cron TOML reference + common patterns
│
└── telegram/
    └── stickers-emoji.md            # Generate and upload sticker/emoji packs via agent
```

---

## Sections

**vpn** — Aggregate your VLESS key with igareck community pools, publish as subscription
URLs to a public git repo, auto-update every hour.

**cloudflare** — Full lifecycle for Cloudflare Workers: account setup, API token,
deploy via wrangler or GitHub Actions, KV storage from Worker code and from agent REST calls.

**voice** — Bring-your-own-key Deepgram setup for speech transcription (no shared quotas,
$0.06/hr). Voice cloning guide coming once the Nano pipeline is production-ready.

**networking** — Tailscale userspace tunnel that works inside a rootless Docker container.
Your agent becomes reachable on your Tailnet without any VPS or open ports.

**monitoring** — Session watchdog pattern: detect when an agent turn goes silent for
10+ min and fire a Telegram alert to the right topic. Also: findings board template
for multi-agent research sprints.

**research** — `pwc_search.sh`: query PapersWithCode API for papers, datasets, and methods
from a single bash one-liner. `jina-reader.md`: strip any public page to clean markdown
in one curl call. `agent-browser.md`: headless Chrome for sites that block scrapers or
require login — click, fill forms, save auth cookies.

**github** — Decision tree for reading files, exploring repos, creating issues and PRs,
merging, and pushing — all without a browser. Python `urllib` patterns, `gh` CLI caveats,
token setup.

**chat-management** — How `topics.json`, `topic_loader`, and `override.md` interact.
Override files are intentionally lean; this guide explains why and how to structure them.

**scheduling** — lisa-cron TOML quick reference. Common patterns: every 5 min, hourly,
daily at a fixed local time. Timezone field, timeout_secs, job anatomy.

**telegram** — Generate images, resize to Telegram spec, upload as sticker or custom
emoji pack. Static, animated, and video sticker requirements.

---

## Contributing

File an issue or open a PR. Keep the writing style: direct, concise, actionable.
If a step needs code, include working code. If a step needs a command, include the
exact command.
