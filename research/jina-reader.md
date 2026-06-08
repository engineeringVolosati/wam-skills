# Jina Reader — fetch web pages as clean markdown

## What it does

Jina Reader (`r.jina.ai`) converts any public URL into clean markdown by stripping JavaScript, CSS, ads, and navigation chrome. The result is 2–3x smaller than raw HTML — fewer tokens, faster processing, no noise.

No API key required. Free for public use.

## When to use

**Use Jina when:**
- You need the text of a plain public page — fastest and cheapest option.
- You want a specific section: fetch via Jina, then grep by heading.

**Do NOT use Jina when:**
- **GitHub repo or file** → use `raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>` directly. It's faster, exact, and returns the raw file without Jina's markdown conversion overhead.
- **JS-heavy page, Cloudflare/PerimeterX/Akamai protection, or login required** → use `agent-browser` instead. Jina fetches static HTML only and cannot bypass bot protection or render JS.
- **Full page render needed** → use `WebFetch`.
- **Single trusted HTTP request** → `curl` or `WebFetch` is enough.

## Basic usage

```sh
curl -s "https://r.jina.ai/https://example.com"
```

Replace `https://example.com` with the target URL. The output is clean markdown.

## Useful headers

```sh
# Structured JSON output (includes title, description, content)
curl -s -H "Accept: application/json" "https://r.jina.ai/https://example.com"

# Include a summary of all links found on the page
curl -s -H "X-With-Links-Summary: true" "https://r.jina.ai/https://example.com"
```

## Fetch + grep a specific section

```sh
curl -s "https://r.jina.ai/https://example.com" | grep -A 20 "## Installation"
```

## Rate limits and cost

- No API key needed.
- No hard rate limits for reasonable use.
- Free tier covers all normal agent workloads.

## Common pitfall

Using Jina for GitHub repos or raw files is slower and less precise than going direct:

```sh
# Wrong — Jina adds markdown conversion overhead and may truncate
curl -s "https://r.jina.ai/https://github.com/owner/repo/blob/main/README.md"

# Correct — raw content, exact bytes
curl -s "https://raw.githubusercontent.com/owner/repo/main/README.md"
```
