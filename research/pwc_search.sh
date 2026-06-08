#!/usr/bin/env bash
# pwc_search.sh — PapersWithCode API search CLI
#
# Usage:
#   pwc_search.sh "<query>" [papers|datasets|methods]
#
# Examples:
#   pwc_search.sh "object detection"
#   pwc_search.sh "image segmentation" papers
#   pwc_search.sh "MNIST" datasets
#   pwc_search.sh "attention" methods
#
# Outputs top results in plain text. Requires curl and jq.
# Falls back gracefully if API is unreachable.

set -euo pipefail

QUERY="${1:-}"
TYPE="${2:-papers}"
BASE_URL="https://paperswithcode.com/api/v1"
MAX_RESULTS=10

if [[ -z "$QUERY" ]]; then
    echo "Usage: pwc_search.sh \"<query>\" [papers|datasets|methods]" >&2
    exit 1
fi

case "$TYPE" in
    papers|datasets|methods) ;;
    *)
        echo "Unknown type: $TYPE. Use: papers, datasets, or methods" >&2
        exit 1
        ;;
esac

# URL-encode the query
encode_query() {
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

ENCODED=$(encode_query "$QUERY")
URL="${BASE_URL}/${TYPE}/?q=${ENCODED}&items_per_page=${MAX_RESULTS}"

echo "Searching PapersWithCode for \"${QUERY}\" in ${TYPE}..."
echo ""

# Try to fetch; fall back gracefully on error
if ! RESPONSE=$(curl -sf --max-time 10 "$URL" 2>/dev/null); then
    echo "Could not reach PapersWithCode API (${URL})." >&2
    echo "Check your internet connection or try again later." >&2
    exit 1
fi

# Check for empty or error response
if [[ -z "$RESPONSE" ]]; then
    echo "Empty response from API." >&2
    exit 1
fi

COUNT=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('count', 0))" 2>/dev/null || echo 0)
echo "Found ${COUNT} result(s). Showing top ${MAX_RESULTS}:"
echo ""

case "$TYPE" in
    papers)
        echo "$RESPONSE" | python3 - << 'PYEOF'
import json, sys, textwrap

data = json.load(sys.stdin)
results = data.get("results", [])

if not results:
    print("No results found.")
    sys.exit(0)

for i, paper in enumerate(results, 1):
    title = paper.get("title", "—")
    arxiv_id = paper.get("arxiv_id") or ""
    url = paper.get("url_abs") or (f"https://arxiv.org/abs/{arxiv_id}" if arxiv_id else "")
    paper_url = paper.get("paper_page") or url or ""
    stars = paper.get("github_stars") or paper.get("stars") or 0
    tasks = ", ".join(t.get("name", "") for t in (paper.get("tasks") or [])[:3])
    published = paper.get("published") or paper.get("date") or ""

    print(f"{i}. {title}")
    if published:
        print(f"   Published: {published}")
    if tasks:
        print(f"   Tasks: {tasks}")
    if stars:
        print(f"   Stars: {stars}")
    if arxiv_id:
        print(f"   arXiv: https://arxiv.org/abs/{arxiv_id}")
    if paper_url:
        print(f"   PwC:   {paper_url}")
    print()
PYEOF
        ;;

    datasets)
        echo "$RESPONSE" | python3 - << 'PYEOF'
import json, sys

data = json.load(sys.stdin)
results = data.get("results", [])

if not results:
    print("No results found.")
    sys.exit(0)

for i, ds in enumerate(results, 1):
    name = ds.get("name", "—")
    full_name = ds.get("full_name") or name
    url = ds.get("url") or f"https://paperswithcode.com/dataset/{ds.get('id','')}"
    modalities = ", ".join(ds.get("modalities") or [])
    tasks = ", ".join(t.get("name", "") for t in (ds.get("tasks") or [])[:3])
    intro = (ds.get("abstract") or ds.get("description") or "")[:150]

    print(f"{i}. {full_name}")
    if modalities:
        print(f"   Modalities: {modalities}")
    if tasks:
        print(f"   Tasks: {tasks}")
    if intro:
        print(f"   {intro.strip()}{'...' if len(intro) == 150 else ''}")
    print(f"   URL: {url}")
    print()
PYEOF
        ;;

    methods)
        echo "$RESPONSE" | python3 - << 'PYEOF'
import json, sys

data = json.load(sys.stdin)
results = data.get("results", [])

if not results:
    print("No results found.")
    sys.exit(0)

for i, method in enumerate(results, 1):
    name = method.get("name", "—")
    full_name = method.get("full_name") or name
    url = method.get("url") or f"https://paperswithcode.com/method/{method.get('id','')}"
    area = method.get("area") or method.get("category") or ""
    intro = (method.get("paper_count") or "")
    desc = (method.get("description") or "")[:150]

    print(f"{i}. {full_name}")
    if area:
        print(f"   Area: {area}")
    if intro:
        print(f"   Papers using this: {intro}")
    if desc:
        print(f"   {desc.strip()}{'...' if len(desc) == 150 else ''}")
    print(f"   URL: {url}")
    print()
PYEOF
        ;;
esac
