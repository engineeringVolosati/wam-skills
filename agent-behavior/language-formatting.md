# Agent language & formatting discipline

Rules for every WAM agent regardless of user language or topic.

---

## Language

**Prompts and internal docs** — English.

This includes: `CLAUDE.md`, `system.md`, `override.md`, REGISTRY.md entries,
code comments, GitHub issues, PRs, sub-agent prompts, inline task plans.

Reason: prompts are read by the model, not the user. English tokenizes ~30–50%
more efficiently than Cyrillic for the same semantic content. Keeping docs in
English also makes them readable by any LLM and any contributor.

**Replies to user** — match the user's language.
Detect from first message; default to Russian if ambiguous.

**User task notes and memory** — user's language.

When you write notes visible to the user — task descriptions in TodoWrite,
memory entries about the user's projects and preferences, reminders text,
planning summaries shown in chat — write in the user's language.
Reason: context built in the user's language survives across sessions without
semantic drift from translation. A Russian-speaking user's task context should
stay in Russian.

**Reasoning on large tasks** — think in the most token-efficient language.

For complex multi-step tasks where chain-of-thought spans many tokens, prefer
English internally. Cyrillic text inflates context ~1.5× per unit of meaning.
The model produces more compact reasoning in English.

Summary: reply in user's language · write user-visible notes in user's language · write docs in English · think in English.

---

## Code blocks

Always use a fenced block with a language tag. No exceptions, including
one-liners and shell commands:

```python
x = 1 + 1
```

```sh
python3 scripts/foo.py --arg value
```

Copy-paste text that is not code — use a plain `text` fence:

```text
Some literal string to paste
```

**In Telegram specifically:** inline backticks (`` `code` ``) render as plain
text with no monospace formatting. Never use inline backticks for code or
commands in Telegram — always use fenced blocks.

---

## Links

**In docs and code** — standard markdown: `[display text](https://url)`.

**In Telegram messages:**

- Bare `https://` URLs render as native clickable links. Use for one-off URLs.
- Named links require HTML parse mode: `<a href="https://url">text</a>`.
  Pass `parse_mode="HTML"` when you need named links in `telegram_reply` or
  `telegram_send_message`. Markdown parse mode in Telegram is unpredictable —
  prefer HTML when link text matters.
- Never embed long raw URLs in the middle of prose — they break line flow
  on mobile.

**File paths in messages** — always backtick-wrapped: `scripts/foo.py`.
Never expose `/home/username/` prefix — show paths relative to workspace root.
