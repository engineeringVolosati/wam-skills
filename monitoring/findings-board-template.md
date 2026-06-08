# Findings board — template for parallel agent research

When multiple agents (or agent + human) work on the same research question in parallel,
you need a shared board to avoid duplication, surface the best results, and keep
momentum between sessions.

This template is designed to be:
- Checked in to a repo alongside the research task
- Read by agents at the start of each session
- Updated by whichever agent finds something

---

## How to use

1. Copy the template below into `findings.md` at the root of your research task folder.
2. Each agent reads `findings.md` at session start before doing anything.
3. After each meaningful attempt, the agent updates the relevant section.
4. The human reviews at natural breakpoints — not after every micro-step.
5. When a result is clearly best, it moves to **Champion**.

---

## Template

```markdown
# Findings — [Task name]

Last updated: [ISO timestamp]
Updated by: [agent name / human]

---

## Champion

*The single best result so far. Everything else is judged against this.*

| Metric | Value |
|--------|-------|
| [Key metric 1] | — |
| [Key metric 2] | — |

Config / approach:
[Describe what produced this result — enough detail to reproduce it]

---

## What works

*Confirmed approaches, patterns, settings that reliably improve results.*

- [Finding 1] — [brief note on how/why]
- [Finding 2]
- [Finding 3]

---

## Dead ends

*Things tried that didn't work or made results worse. Don't retry these.*

- [Approach 1] — [why it failed or what happened]
- [Approach 2]
- [Approach 3]

---

## Open directions

*Hypotheses not yet tested. Pick from here when choosing what to try next.*

Priority order (top = most promising):

1. [Direction 1] — [rationale]
2. [Direction 2]
3. [Direction 3]

---

## Next levers

*Specific parameters or variables to tune in the next session.*

- [ ] [Lever 1] — current: X, try: Y, reason: Z
- [ ] [Lever 2]
- [ ] [Lever 3]

---

## Session log

*One-line summary per session. Newest first.*

| Date | Agent | Summary |
|------|-------|---------|
| [date] | [agent] | [what was tried, what was found] |
```

---

## Update discipline

**After every session, the agent must:**

1. Move the best result to Champion if it beats the current champion.
2. Add any confirmed patterns to "What works".
3. Add any failed approaches to "Dead ends".
4. Remove tested directions from "Open directions".
5. Update "Next levers" based on what the session revealed.
6. Add one line to the session log.

**Don't:**
- Leave "Open directions" full of things already tried.
- Keep a Champion that's been beaten.
- Skip the session log entry — it's the only way to avoid re-running the same experiments.

---

## Example (filled in)

```markdown
# Findings — VLESS latency optimization

Last updated: 2026-06-08T14:32:00+03:00
Updated by: agent-research-1

---

## Champion

*Best result as of 2026-06-08*

| Metric | Value |
|--------|-------|
| P50 latency | 38ms |
| P99 latency | 120ms |
| Packet loss | 0.2% |

Config: Reality + Vision + multiplexing disabled, MTU 1200, port 443

---

## What works

- Port 443 consistently beats 8443 (CDN-friendly, less filtering)
- MTU 1200 reduces fragmentation on mobile networks
- Reality > TLS 1.3 for fingerprint resistance

---

## Dead ends

- UDP-based transport (QUIC) — mobile operators drop UDP aggressively in RU
- Multiplexing — increases latency variance at low-concurrency load
- Port 80 — blocked at most residential ISPs tested

---

## Open directions

1. Test SNI rotation — may help with DPI detection on longer sessions
2. Compare Vision vs H2 on LTE vs WiFi separately
3. Try obfs4 as outer layer — untested, might reduce DPI signature

---

## Next levers

- [ ] SNI field — current: static domain, try: rotating pool, reason: reduce pattern
- [ ] Keep-alive interval — current: 30s, try: 15s, reason: mobile NAT timeouts

---

## Session log

| Date | Agent | Summary |
|------|-------|---------|
| 2026-06-08 | research-1 | Tested ports 443/80/8443. 443 wins. MTU 1200 confirmed better. |
| 2026-06-07 | human | Initial setup, baseline measured at P50=95ms |
```
