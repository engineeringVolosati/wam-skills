# Topic override pattern in WAM agents

How `topics.json`, `topic_loader`, and `override.md` work together to give each
Telegram topic its own personality, context, and constraints — without touching
the shared system prompt.

---

## Architecture

```
topics.json
    └── registers topic metadata (chat_id, thread_id, name, override path)

topic_loader.py (hook, runs on every turn)
    └── reads topics.json
    └── finds the current topic by chat_id + thread_id
    └── reads override.md for that topic
    └── injects content into the system prompt prefix

override.md (per-topic file)
    └── lean pointer file OR inline content
    └── loaded fresh on every turn — no caching
```

The key property: every topic is a separate context bubble. The same agent
responds differently in a code review thread vs a personal chat vs a team
planning channel — because the override injects different instructions.

---

## topics.json structure

```json
{
  "topics": [
    {
      "chat_id": -1001234567890,
      "thread_id": 42,
      "name": "MYPROJECT-MAIN",
      "override": "projects/myproject/override.md",
      "dashboard": true
    },
    {
      "chat_id": -1001234567890,
      "thread_id": null,
      "name": "MYPROJECT-DM",
      "override": "projects/myproject/dm-override.md",
      "dashboard": false
    }
  ]
}
```

`thread_id: null` matches the top-level chat (no topic thread).
`override` is a path relative to the workspace root.

---

## override.md — intentionally lean

The override file should be **a pointer, not a dump**. Why:

- It's injected on every turn — fat files = fat context = higher cost and slower responses.
- Expanded context lives in separate files that the agent reads on demand.
- The override tells the agent *where* to look, not everything it needs to know upfront.

### Minimal override structure

```markdown
# [TOPIC NAME] context

**Role in this thread:** [one sentence — what the agent does here]

**Owner:** [person or team]

## Key files to read on demand

- `projects/myproject/STATE.md` — current project status
- `projects/myproject/architecture.md` — system design
- `projects/myproject/tasks/` — active task files

## Constraints

- [Specific rule for this topic, e.g. "always ask before merging PRs"]
- [Another constraint, e.g. "English only in this thread"]

## Persistent context

[1-3 lines of essential context that must always be active, e.g.
"This is a production system. Any deploy requires confirmation."]
```

### What NOT to put in override.md

- Full documentation dumps
- Long histories or logs
- Content that changes often (link to it instead)
- Content that's already in MEMORY.md or system.md

---

## Priority chain

When the agent receives a message, injected context is layered in this order
(later layers can override earlier ones):

1. `system.md` — base platform rules, identity, Telegram transport
2. `agent.md` — persona (Лиса, or whatever the client named their agent)
3. `delegation.md` — autonomy levels
4. `rules.md` — global rules (always first in CLAUDE.md via @include)
5. **`override.md` for the current topic** ← this is where per-topic rules live
6. MEMORY.md — persistent cross-session facts

Topic override wins over persona but not over platform safety rules.
It cannot, for example, override "never expose credentials" or the Telegram
transport contract.

---

## Chat override vs topic override

| | Chat override | Topic override |
|---|---|---|
| Scope | All threads in a chat | Specific thread (chat_id + thread_id) |
| File | `projects/chatname/override.md` | `projects/chatname/threadname/override.md` |
| Use case | Group-wide rules | Per-topic context (code, planning, personal) |

If both exist, topic override takes precedence for messages in that thread.

---

## Registering a new topic

Option A — via CLI:

```sh
python3 scripts/register_topic.py \
  --chat-id -1001234567890 \
  --thread-id 42 \
  --name "MYPROJECT-MAIN" \
  --override "projects/myproject/override.md"
```

Option B — `topic_loader` auto-registers on first message if the topic is
unknown. It creates a minimal entry in `topics.json` with no override path.
You then add the override path manually.

---

## Editing overrides

Topic overrides are instance-writable (no issue required). Any agent instance
can edit its own topic's `override.md`. Schema changes to `topics.json` itself
require a lisa-core issue.

Direct path: edit the file, changes take effect on the next turn — no restart needed.
