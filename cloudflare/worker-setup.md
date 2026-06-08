# Cloudflare Worker setup

Full lifecycle: account creation, API token, deploy via wrangler CLI or GitHub Actions,
KV storage from Worker code, KV read/write from agent side via REST API.

---

## 1. Create a Cloudflare account

Go to [dash.cloudflare.com](https://dash.cloudflare.com) and sign up.
Free tier is sufficient for Workers + KV (100k requests/day, 1 GB KV storage).

---

## 2. Get your Account ID

In the Cloudflare dashboard: click any domain (or go to **Workers & Pages** in the
left sidebar) → look at the right sidebar under **Account ID**.

Copy it — you'll need it for wrangler and for REST API calls.

---

## 3. Create an API Token

Go to **My Profile → API Tokens → Create Token**.

Use the **Edit Cloudflare Workers** template, or create a custom token with:

| Permission | Level |
|-----------|-------|
| Account — Workers Scripts | Edit |
| Account — Workers KV Storage | Edit |
| Account — Workers Routes | Edit |
| Zone — Workers Routes | Edit *(optional, only if binding to a custom domain)* |

Set **Account Resources** to your specific account (not "All accounts").
Click **Continue to summary → Create Token**.

Copy the token immediately — it's shown only once.

Store it in your agent:

```sh
# via agent secret store
python3 scripts/superlisa_store_secret.py CLOUDFLARE_API_TOKEN your_token_here
python3 scripts/superlisa_store_secret.py CLOUDFLARE_ACCOUNT_ID your_account_id_here
```

---

## 4. Deploy via wrangler CLI

### Install wrangler

```sh
npm install -g wrangler
```

### Authenticate

```sh
export CLOUDFLARE_API_TOKEN=your_token_here
```

(Or run `wrangler login` for browser-based OAuth — use the token method for automated/agent use.)

### Create a Worker project

```sh
mkdir my-worker && cd my-worker
wrangler init --yes
```

This creates `wrangler.toml` and `src/index.js`.

### Minimal wrangler.toml

```toml
name = "my-worker"
main = "src/index.js"
compatibility_date = "2024-01-01"
account_id = "your_account_id_here"

[[kv_namespaces]]
binding = "MY_KV"
id = "your_kv_namespace_id"
```

### Deploy

```sh
wrangler deploy
```

Your worker is live at `https://my-worker.your-subdomain.workers.dev`.

---

## 5. Deploy via GitHub Actions (preferred for automated workflows)

Create `.github/workflows/deploy.yml` in your worker repo:

```yaml
name: Deploy Worker

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    name: Deploy
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Cloudflare Workers
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

In your GitHub repo: **Settings → Secrets and variables → Actions** → add
`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.

Push to `main` and the Worker deploys automatically.

---

## 6. Create a KV namespace

```sh
wrangler kv namespace create MY_KV
```

This outputs a namespace ID. Put it in `wrangler.toml` under `[[kv_namespaces]]`.

For a preview namespace (used during `wrangler dev`):

```sh
wrangler kv namespace create MY_KV --preview
```

---

## 7. KV storage from Worker code

```javascript
// src/index.js
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname.startsWith("/get/")) {
      const key = url.pathname.slice(5);
      const value = await env.MY_KV.get(key);
      if (value === null) {
        return new Response("Not found", { status: 404 });
      }
      return new Response(value, { headers: { "Content-Type": "text/plain" } });
    }

    if (request.method === "PUT" && url.pathname.startsWith("/set/")) {
      const key = url.pathname.slice(5);
      const value = await request.text();
      await env.MY_KV.put(key, value);
      return new Response("OK");
    }

    return new Response("Not found", { status: 404 });
  },
};
```

---

## 8. Read/write KV from agent side via Cloudflare REST API

The agent doesn't need to go through the Worker — it can read and write KV directly
using the Cloudflare REST API.

### Write a key

```sh
curl -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/storage/kv/namespaces/${KV_NAMESPACE_ID}/values/my-key" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: text/plain" \
  --data "my value"
```

### Read a key

```sh
curl \
  "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/storage/kv/namespaces/${KV_NAMESPACE_ID}/values/my-key" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
```

### List keys

```sh
curl \
  "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/storage/kv/namespaces/${KV_NAMESPACE_ID}/keys" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
```

### Python helper

```python
import os
import urllib.request
import json

CF_TOKEN = os.environ["CLOUDFLARE_API_TOKEN"]
CF_ACCOUNT = os.environ["CLOUDFLARE_ACCOUNT_ID"]
KV_NS = os.environ["KV_NAMESPACE_ID"]

BASE = f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT}/storage/kv/namespaces/{KV_NS}"
HEADERS = {"Authorization": f"Bearer {CF_TOKEN}"}


def kv_get(key: str) -> str | None:
    req = urllib.request.Request(f"{BASE}/values/{key}", headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as r:
            return r.read().decode()
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def kv_put(key: str, value: str) -> None:
    data = value.encode()
    req = urllib.request.Request(
        f"{BASE}/values/{key}", data=data, method="PUT",
        headers={**HEADERS, "Content-Type": "text/plain"}
    )
    urllib.request.urlopen(req)
```

---

## Gotchas

- KV is **eventually consistent** — writes propagate globally in ~60 seconds.
  Don't use it for things that need instant read-after-write.
- Free tier KV limit: 1000 write operations/day. Reads are 10M/day.
- Worker free tier: 100k requests/day, 10ms CPU time per request.
  For CPU-heavy work, consider **Workers Unbound** (pay-per-use).
- `wrangler dev` runs your Worker locally but uses a preview KV namespace —
  separate from production. Don't mix up namespace IDs.
