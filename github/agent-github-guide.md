# GitHub for AI agents

How to read, search, and act on GitHub from your agent — without a browser.

## Decision tree

| Task | Tool |
|------|------|
| Read a single file | `raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>` |
| Explore a whole repo | `gitingest <url>` (structure + key files in one shot) |
| Create issues / PRs / comments | GitHub REST API via `urllib` or `gh` CLI |
| Search code across repos | `gh api search/code` |
| Merge, close, label | GitHub REST API |

---

## Reading files — raw.githubusercontent.com

The fastest way to read any public file:

```sh
curl -s "https://raw.githubusercontent.com/owner/repo/main/path/to/file.py"
```

In Python:
```python
import urllib.request
with urllib.request.urlopen(
    "https://raw.githubusercontent.com/owner/repo/main/README.md"
) as r:
    content = r.read().decode()
```

Never use Jina or WebFetch for GitHub file reads — raw URL is exact and instant.

---

## Exploring a repo — gitingest

`gitingest` fetches the repo structure + key file contents in one call.

```sh
# CLI (if installed)
gitingest https://github.com/owner/repo

# Python module
python3 -m gitingest https://github.com/owner/repo
```

Returns a structured digest: directory tree + file contents concatenated.
Use it when you need to understand a whole codebase, not just one file.

If `gitingest` isn't installed or fails (GitHub auth issues in some envs),
fall back to the GitHub API:

```sh
# List files in a directory
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/owner/repo/contents/path"
```

---

## Authentication

Store your token in `.secrets/.env`:

```
GITHUB_TOKEN=ghp_...
```

Read it in scripts:
```python
import os, pathlib

def _gh_token() -> str:
    for key in ("GITHUB_TOKEN", "GH_TOKEN"):
        t = os.environ.get(key, "")
        if t:
            return t
    env = pathlib.Path(".secrets/.env")
    if env.exists():
        for line in env.read_text().splitlines():
            if line.startswith("GITHUB_TOKEN="):
                return line.split("=", 1)[1].strip()
    raise RuntimeError("No GitHub token found")
```

**Token scopes needed:**
- `repo` — read/write private repos, create issues/PRs
- `gist` — create/update gists
- `read:org` — list org repos

Classic PAT, no expiry recommended for agent use. Create at:
**GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**

---

## Creating issues via API

```python
import urllib.request, json

def create_issue(repo: str, title: str, body: str, token: str) -> dict:
    payload = json.dumps({"title": title, "body": body}).encode()
    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/issues",
        data=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

result = create_issue("owner/repo", "Bug: something broke", "Details here...", token)
print(result["html_url"])
```

---

## Merging a PR via API

```python
def merge_pr(repo: str, pr_number: int, token: str, method: str = "squash") -> bool:
    pr_req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/pulls/{pr_number}",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}
    )
    with urllib.request.urlopen(pr_req) as r:
        pr = json.loads(r.read())
    sha = pr["head"]["sha"]

    payload = json.dumps({"merge_method": method, "sha": sha}).encode()
    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/pulls/{pr_number}/merge",
        data=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
        },
        method="PUT",
    )
    try:
        with urllib.request.urlopen(req) as r:
            return True
    except Exception:
        return False
```

---

## gh CLI (when available)

`gh` CLI wraps the API but needs auth:

```sh
# Auth with a token (pipe it in — no interactive prompt)
echo "$GITHUB_TOKEN" | gh auth login --with-token

# But: if GITHUB_TOKEN env var is set, gh uses it automatically
GITHUB_TOKEN=ghp_... gh issue list --repo owner/repo
```

**Caveat:** if `GITHUB_TOKEN` env var is set before you run `gh auth login --with-token`,
gh CLI errors out ("env var is being used"). Unset it first or just use the API directly.

For most agent workflows, calling the API directly with `urllib` is more reliable
than the `gh` CLI — no auth conflicts, no PATH dependency.

---

## Watching a repo for events

See `monitoring/session-watchdog.md` for the polling pattern.
For GitHub-specific event watching: poll `/repos/{repo}/events` or
`/repos/{repo}/issues?state=all&sort=updated&since=<ISO>` every 60s.

---

## Push without SSH

Agent containers typically don't have SSH keys. Use HTTPS with token:

```sh
git remote set-url origin "https://$GITHUB_TOKEN@github.com/owner/repo.git"
git push origin main
```

Set the remote URL before every push session — don't store credentials in `.git/config`.
