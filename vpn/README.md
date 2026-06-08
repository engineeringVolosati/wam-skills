# VPN key aggregation

Merge your own VLESS key with three igareck community pools and publish the result
as subscription URLs from a public git repo. Karing, Throne, and any subscription-aware
client can poll the raw URLs and stay current automatically.

---

## How it works

1. You have a personal VLESS key (from a bot, a friend, a webhook — doesn't matter).
2. `update.py` fetches three upstream pools from `github.com/igareck/vpn-configs-for-russia`.
3. Your key is prepended to each merged list.
4. The script commits and pushes to a public repo.
5. Raw `githubusercontent.com` URLs become your subscription endpoints.
6. A lisa-cron job runs `update.py` every hour.

---

## Setup

### 1. Create a public repo for your subscriptions

Create a new public GitHub repo, e.g. `yourname/vpn-sub`.
Clone it locally (or on your agent server):

```sh
git clone https://github.com/yourname/vpn-sub.git
cd vpn-sub
```

### 2. Store your personal key

Create `key.txt` in the repo root and paste your VLESS key (one key per line).
Add it to `.gitignore` immediately — your key must never be committed:

```sh
echo "vless://..." > key.txt
echo "key.txt" >> .gitignore
```

### 3. Add the aggregator script

Copy `update.py` (see below) into the repo root.

### 4. Configure Git credentials for automated push

On the machine running the agent, store a GitHub token in the agent's secret store:

```sh
python3 scripts/superlisa_store_secret.py GITHUB_SUB_TOKEN ghp_...
```

Or export it in the environment before running the script. `update.py` reads
`GITHUB_SUB_TOKEN` (falls back to `GITHUB_TOKEN`).

### 5. Schedule with lisa-cron

Add to your `lisa-cron` config (see `scheduling/lisa-cron-quickstart.md`):

```toml
[[jobs]]
name = "vpn-sub-update"
schedule = "0 * * * *"   # every hour
command = "python3 /path/to/vpn-sub/update.py"
timeout_secs = 120
```

---

## The upstream pools

| File | Description |
|------|-------------|
| `BLACK_VLESS_RUS.txt` | Desktop/broadband pool |
| `BLACK_VLESS_RUS_mobile.txt` | Mobile pool |
| `Vless-Reality-White-Lists-Rus-Mobile.txt` | Reality whitelist mobile |

Source: `https://raw.githubusercontent.com/igareck/vpn-configs-for-russia/main/`

---

## update.py

```python
#!/usr/bin/env python3
"""
update.py — merge personal VLESS key with igareck community pools,
commit and push to a public subscription repo.
"""

import os
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO_DIR = Path(__file__).parent.resolve()

UPSTREAM_BASE = (
    "https://raw.githubusercontent.com/igareck/vpn-configs-for-russia/main/"
)

POOLS = [
    "BLACK_VLESS_RUS.txt",
    "BLACK_VLESS_RUS_mobile.txt",
    "Vless-Reality-White-Lists-Rus-Mobile.txt",
]

KEY_FILE = REPO_DIR / "key.txt"
OUT_DIR = REPO_DIR / "subscriptions"


def fetch(url: str) -> list[str]:
    """Fetch a URL, return non-empty lines."""
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            text = resp.read().decode("utf-8", errors="replace")
        return [ln.strip() for ln in text.splitlines() if ln.strip()]
    except Exception as exc:
        print(f"[warn] could not fetch {url}: {exc}", file=sys.stderr)
        return []


def read_personal_keys() -> list[str]:
    """Read personal keys from key.txt (gitignored)."""
    if not KEY_FILE.exists():
        print("[warn] key.txt not found — output will have no personal key", file=sys.stderr)
        return []
    return [ln.strip() for ln in KEY_FILE.read_text().splitlines() if ln.strip()]


def merge(personal: list[str], upstream: list[str]) -> list[str]:
    """Personal keys first, then upstream (deduped, order preserved)."""
    seen: set[str] = set()
    result: list[str] = []
    for key in personal + upstream:
        if key not in seen:
            seen.add(key)
            result.append(key)
    return result


def git(*args: str) -> None:
    subprocess.run(["git", "-C", str(REPO_DIR), *args], check=True)


def push() -> None:
    token = os.environ.get("GITHUB_SUB_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        # Inject token into remote URL for automated push
        result = subprocess.run(
            ["git", "-C", str(REPO_DIR), "remote", "get-url", "origin"],
            capture_output=True, text=True
        )
        origin = result.stdout.strip()
        if "https://" in origin and "@" not in origin:
            authed = origin.replace("https://", f"https://x-token:{token}@")
            subprocess.run(
                ["git", "-C", str(REPO_DIR), "remote", "set-url", "origin", authed],
                check=True
            )
    git("push", "origin", "HEAD")


def main() -> None:
    OUT_DIR.mkdir(exist_ok=True)
    personal = read_personal_keys()

    changed = False
    for pool_file in POOLS:
        url = UPSTREAM_BASE + pool_file
        print(f"[info] fetching {pool_file}...")
        upstream = fetch(url)
        merged = merge(personal, upstream)

        out_path = OUT_DIR / pool_file
        new_content = "\n".join(merged) + "\n"

        if out_path.exists() and out_path.read_text() == new_content:
            print(f"[skip] {pool_file} unchanged")
            continue

        out_path.write_text(new_content)
        print(f"[ok]   {pool_file}: {len(merged)} keys ({len(personal)} personal + {len(upstream)} upstream)")
        changed = True

    if not changed:
        print("[info] nothing changed, no commit needed")
        return

    git("add", "subscriptions/")
    git("commit", "-m", "chore: update vpn subscriptions")
    push()
    print("[ok] pushed")


if __name__ == "__main__":
    main()
```

---

## Your subscription URLs

After the first successful run, your subscription files will be at:

```
https://raw.githubusercontent.com/yourname/vpn-sub/main/subscriptions/BLACK_VLESS_RUS.txt
https://raw.githubusercontent.com/yourname/vpn-sub/main/subscriptions/BLACK_VLESS_RUS_mobile.txt
https://raw.githubusercontent.com/yourname/vpn-sub/main/subscriptions/Vless-Reality-White-Lists-Rus-Mobile.txt
```

Paste these into Karing or Throne as subscription sources.
See `karing-throne-setup.md` for exactly where to paste them.

---

## .gitignore

Your repo's `.gitignore` should include at minimum:

```
key.txt
*.env
.env
```
