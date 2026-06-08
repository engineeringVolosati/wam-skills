# Telegram userbot — setup and rules

A userbot acts as the account owner, not as a bot. It can do things the Bot API
cannot: read any chat, send messages from a real account, join groups without
an invite link, access message history. This power comes with strict rules.

---

## Setup

### 1. Get API credentials

Go to **https://my.telegram.org** → API development tools.
Create an app. You get `api_id` (integer) and `api_hash` (string).

Store them in `.secrets/.env`:
```text
TELEGRAM_API_ID=12345678
TELEGRAM_API_HASH=abcdef1234567890abcdef1234567890
```

### 2. Install Telethon

```sh
pip install --user telethon
```

### 3. First authorization (interactive, one time)

```python
from telethon.sync import TelegramClient

api_id = 12345678
api_hash = "abcdef..."
client = TelegramClient("volosati", api_id, api_hash)

with client:
    client.start()  # prompts for phone number, then code, then 2FA password
    print("Authorized. Session saved to volosati.session")
```

Run this **once interactively** — on the machine where you can enter the code.
The resulting `volosati.session` file is the auth token. Store it securely;
anyone with this file has full account access.

After first auth, all future calls use the session silently — no prompts.

### 4. Sending a message (fire and forget)

```python
from telethon.sync import TelegramClient

def send_to_thread(chat_id: int, thread_id: int, text: str) -> None:
    with TelegramClient("volosati", API_ID, API_HASH) as client:
        client.send_message(
            entity=chat_id,
            message=text,
            reply_to=thread_id,  # forum thread = reply_to topic root message
        )
```

For supergroup forum topics `reply_to=thread_id` sends into that topic.

### 5. Queue pattern (agent-safe)

Direct Telethon calls from an agent are fragile — if the agent dies mid-call
the session file may be left locked. Use a **file queue + dedicated runner** instead:

```text
queue/pending/<task_id>.json  →  queue_runner.py  →  Telethon send
```

`queue_runner.py` owns the session, drains the queue atomically, handles
FloodWait. The agent only writes JSON files — no Telethon import in agent code.

---

## Rules

### Sign every external message

When the userbot sends a message to any person or group that is not the owner's
own infrastructure, prepend a signature:

```text
Это Андрей, пишу через своего агента (Лису).
```

Never impersonate the owner silently. Third parties must know they are reading
agent-generated text, not a human typing in real time.

### Never initiate without explicit permission

The agent must not send a message to any external person or group unless the
owner has explicitly asked for it in the same session. "Same session" means the
current conversation, not a memory from a previous one.

Internal infrastructure chats (your own supergroup topics, your own bots) do
not require explicit permission per message — they are owner's own space.

### Prefer the Bot API

Use the userbot only when the Bot API physically cannot do the task:
- Reading messages not sent to your bot
- Accessing channels where your bot is not a member
- Forwarding or reacting in contexts where bot rights are unavailable

For everything else — `telegram_reply`, `telegram_send_message` via MCP.
The userbot is the last resort, not the default.

---

## Internal use cases

### Wake an agent

Send a trigger message to the topic where the agent lives:

```python
send_to_thread(
    chat_id=-1003824685700,
    thread_id=6,
    text="[wake] check issue queue",
)
```

The bot receives it as a normal message and starts a new turn.

### Broadcast a notification to multiple topics

```python
targets = [
    {"chat_id": -1003824685700, "thread_id": 6},
    {"chat_id": -1003824685700, "thread_id": 4022},
]
for t in targets:
    send_to_thread(t["chat_id"], t["thread_id"], "🆕 issue #42 opened")
    time.sleep(1)  # avoid FloodWait
```

This is how `lisa_core_issue_watcher` notifies all registered agent threads
when a new GitHub issue or PR appears.

### Raise a task with context

```python
body = f"""
[task] Analyze PR #55 in volosati-team/lisa-core
Priority: high
Link: https://github.com/volosati-team/lisa-core/pull/55
""".strip()

send_to_thread(ADMIN_CHAT, ADMIN_THREAD, body)
```

The agent picks it up, reads the issue, comments back.

---

## Limit risks — read before automating

Telegram's FloodWait and account bans are real. The userbot acts as a human
account — Telegram's anti-spam sees no difference.

**What burns limits fast:**

- Polling `get_messages` on many chats in a tight loop — even 1 req/sec
  across 20 chats = 72 000 req/hour. Telegram will FloodWait you.
- Broadcasting to many recipients in quick succession without `time.sleep`.
- Sending the same text repeatedly (looks like spam).
- Uncontrolled agent loops that call `send_message` on every iteration.

**Safe patterns:**

- Poll interval ≥ 60s per chat. Use adaptive polling: longer when idle,
  shorter only after a recent hit.
- Always `time.sleep(1)` between sends in a broadcast loop.
- Gate every send behind a deduplication check (have I sent this already?).
- Register long-running loops in `subagent_watchdog` with a timeout so a
  runaway loop gets killed before it drains everything.
- Never let an agent loop send messages as a side-effect of its main reasoning
  loop. Sends go through the queue; reasoning and sending are separate processes.

**If you hit FloodWait:**

Telethon raises `FloodWaitError(seconds)`. Always catch it:

```python
from telethon.errors import FloodWaitError

try:
    client.send_message(...)
except FloodWaitError as e:
    time.sleep(e.seconds + 5)
```

Ignoring FloodWait and retrying immediately will escalate to a temporary ban.
