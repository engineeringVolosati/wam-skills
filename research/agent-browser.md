# agent-browser — headless Chrome for bot-protected sites

## What it is

`agent-browser` is a Playwright/Chrome wrapper designed for AI agents. It provides:
- Headless Chrome with fingerprint spoofing
- Cloudflare / PerimeterX / Akamai bypass
- Compact DOM snapshots using a ref system (only deltas between steps, ~93% compression)
- Session cookie persistence with encryption

**Binary:** `~/.local/bin/agent-browser` (v0.27.0, installed 2026-06-02)
**Chrome:** `~/.agent-browser/browsers/chrome-149.0.7827.54/`

## When to use

**Use agent-browser when:**
- The site requires login (Facebook, Instagram, Cloudflare dashboard, any SaaS without a public API).
- The page is protected by Cloudflare, PerimeterX, or Akamai — WebFetch and Jina will get blocked.
- The task requires multi-step UI navigation: clicks, form fills, drag-and-drop.
- There is no public API and data is only accessible through the browser UI.

**Do NOT use agent-browser when:**
- You need to read a plain public page → use `curl -s "https://r.jina.ai/<url>"` (10x faster, no Chrome startup cost).
- The service has an API: GitHub → `gh` CLI or GitHub REST API; Telegram → MCP tools.
- A single HTTP request without JS rendering is enough → `curl` or `WebFetch` suffices.

## Basic commands

```sh
# Navigate to a URL
agent-browser go "https://example.com"

# Get a compact DOM snapshot (ref-based, only changed elements)
agent-browser snapshot

# Click an element by its ref ID from the snapshot
agent-browser click <ref>

# Type text into an input element
agent-browser type <ref> "text to type"

# Save the current session cookies to a named profile
agent-browser auth save <profile-name>

# Restore a previously saved session
agent-browser auth load <profile-name>
```

## Token economics

Snapshots use a ref system: only DOM deltas between steps are included, compressing output by ~93% compared to raw HTML. This makes agent-browser significantly cheaper than repeated WebFetch calls for multi-step interactive sessions. For a single static page read, Jina is still faster and cheaper due to Chrome startup overhead.

## Auth persistence

Set `AGENT_BROWSER_ENCRYPTION_KEY` in the environment to enable encrypted cookie storage. After completing a login flow, save the session immediately:

```sh
agent-browser auth save mysite-session
```

On subsequent runs, restore before navigating to skip the login step:

```sh
agent-browser auth load mysite-session
agent-browser go "https://example.com/dashboard"
```

## Practical example: scraping a Cloudflare-protected page

```sh
# 1. Navigate — agent-browser handles the Cloudflare challenge automatically
agent-browser go "https://protected-site.example.com/data"

# 2. Take a snapshot to see current DOM refs
agent-browser snapshot

# 3. If a login form appeared, fill it in using refs from the snapshot
agent-browser type <email-ref> "user@example.com"
agent-browser type <password-ref> "secretpassword"
agent-browser click <submit-ref>

# 4. Snapshot again to confirm login succeeded
agent-browser snapshot

# 5. Save session so future runs skip login
agent-browser auth save protected-site

# 6. Navigate to the target page and snapshot the data
agent-browser go "https://protected-site.example.com/data/export"
agent-browser snapshot
```
