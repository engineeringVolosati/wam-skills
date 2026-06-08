# Session watchdog — detecting hung agent sessions

An agent session goes silent without crashing. No error, no timeout, no log entry —
just stops responding while the spinner keeps spinning. This pattern detects it
and fires a Telegram alert.

---

## How it works

The WAM platform writes a structured log (`wam.log` or equivalent) with one line
per event: `session_start`, `session_end`, `turn_start`, `turn_end`, `inject`.

The watchdog tails this log. For each active session it tracks:
- Time of last `turn_end` or `inject_count_reset` event (heartbeat)
- Whether the session has a `session_end` event (closed cleanly)

If a session is open and the last heartbeat is older than the threshold, the
watchdog fires an alert via Telegram to the session's **source topic**, not a
fixed admin chat.

First alert at **10 minutes** of silence. Repeat at **13 minutes**.

---

## Why "source topic"

Admin chats get noisy. The person who started the stuck session is in the source
topic. That's where the alert is useful. The watchdog reads `chat_id` and
`thread_id` from the session_start log entry and routes the alert there.

---

## Log event structure

The watchdog expects log lines in this format (one JSON object per line):

```json
{"ts": "2026-06-08T10:00:00+03:00", "event": "session_start", "session_id": "abc123", "chat_id": -1001234567890, "thread_id": 42}
{"ts": "2026-06-08T10:00:05+03:00", "event": "turn_start", "session_id": "abc123"}
{"ts": "2026-06-08T10:01:30+03:00", "event": "turn_end", "session_id": "abc123"}
{"ts": "2026-06-08T10:05:00+03:00", "event": "inject", "session_id": "abc123", "inject_count_reset": true}
{"ts": "2026-06-08T10:30:00+03:00", "event": "session_end", "session_id": "abc123"}
```

`inject_count_reset` lines are treated as heartbeats — they indicate the host
process is still alive even if no turn completed.

---

## Watchdog script

```python
#!/usr/bin/env python3
"""
session_watchdog.py — detect hung WAM sessions, alert via Telegram.

Usage:
    python3 session_watchdog.py --check          # one-shot check
    python3 session_watchdog.py --ensure         # start daemon if not running
    python3 session_watchdog.py --daemon         # run as daemon (loop)
"""

import argparse
import json
import os
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

LOG_FILE = Path(os.environ.get("WAM_LOG", "/opt/wam/wam.log"))
PID_FILE = Path("/tmp/session_watchdog.pid")
STATE_FILE = Path("/tmp/session_watchdog.state.json")

ALERT_1_SECS = 10 * 60   # first alert
ALERT_2_SECS = 13 * 60   # repeat alert
CHECK_INTERVAL = 60       # how often to check (seconds)

# Telegram bot token and sender — adjust to your setup
TG_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")


def send_alert(chat_id: int, thread_id: int | None, text: str) -> None:
    """Send a Telegram message via Bot API."""
    if not TG_BOT_TOKEN:
        print(f"[watchdog] no bot token, would alert: {text}", file=sys.stderr)
        return
    payload = {"chat_id": chat_id, "text": text, "parse_mode": "HTML"}
    if thread_id:
        payload["message_thread_id"] = thread_id
    data = json.dumps(payload).encode()
    import urllib.request
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{TG_BOT_TOKEN}/sendMessage",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        urllib.request.urlopen(req, timeout=10)
    except Exception as exc:
        print(f"[watchdog] alert send failed: {exc}", file=sys.stderr)


def parse_ts(ts_str: str) -> float:
    """Parse ISO8601 timestamp to Unix time."""
    try:
        dt = datetime.fromisoformat(ts_str)
        return dt.timestamp()
    except Exception:
        return 0.0


def read_log_tail(path: Path, max_lines: int = 5000) -> list[dict]:
    """Read last N lines of the log, parse as JSON."""
    if not path.exists():
        return []
    try:
        lines = path.read_text(errors="replace").splitlines()
    except Exception:
        return []
    events = []
    for line in lines[-max_lines:]:
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return events


def get_sessions(events: list[dict]) -> dict[str, dict]:
    """
    Build session state from events.
    Returns: {session_id: {chat_id, thread_id, start_ts, last_heartbeat_ts, closed}}
    """
    sessions: dict[str, dict] = {}
    for ev in events:
        sid = ev.get("session_id")
        if not sid:
            continue
        event_type = ev.get("event", "")
        ts = parse_ts(ev.get("ts", ""))

        if event_type == "session_start":
            sessions[sid] = {
                "chat_id": ev.get("chat_id", 0),
                "thread_id": ev.get("thread_id"),
                "start_ts": ts,
                "last_heartbeat_ts": ts,
                "closed": False,
                "alerted_1": False,
                "alerted_2": False,
            }
        elif sid in sessions:
            if event_type in ("turn_end", "turn_start") or ev.get("inject_count_reset"):
                sessions[sid]["last_heartbeat_ts"] = max(
                    sessions[sid]["last_heartbeat_ts"], ts
                )
            if event_type == "session_end":
                sessions[sid]["closed"] = True

    return sessions


def load_alert_state() -> dict:
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except Exception:
            pass
    return {}


def save_alert_state(state: dict) -> None:
    STATE_FILE.write_text(json.dumps(state, indent=2))


def check_once() -> None:
    now = time.time()
    events = read_log_tail(LOG_FILE)
    sessions = get_sessions(events)
    alert_state = load_alert_state()

    for sid, sess in sessions.items():
        if sess["closed"]:
            # Clean up alert state for closed sessions
            alert_state.pop(sid, None)
            continue

        silence = now - sess["last_heartbeat_ts"]
        s = alert_state.setdefault(sid, {"alerted_1": False, "alerted_2": False})

        chat_id = sess["chat_id"]
        thread_id = sess["thread_id"]

        if silence >= ALERT_2_SECS and not s["alerted_2"]:
            send_alert(
                chat_id, thread_id,
                f"<b>Agent session may be hung</b> — no activity for {int(silence // 60)} min.\n"
                f"Session: <code>{sid}</code>\n"
                "Consider /reset or check the server."
            )
            s["alerted_2"] = True
        elif silence >= ALERT_1_SECS and not s["alerted_1"]:
            send_alert(
                chat_id, thread_id,
                f"<b>Agent session quiet for {int(silence // 60)} min</b> — may be working on something long, "
                f"or hung. Will alert again at {ALERT_2_SECS // 60} min if still silent.\n"
                f"Session: <code>{sid}</code>"
            )
            s["alerted_1"] = True

    save_alert_state(alert_state)


def run_daemon() -> None:
    print(f"[watchdog] started, PID={os.getpid()}", flush=True)
    PID_FILE.write_text(str(os.getpid()))
    try:
        while True:
            try:
                check_once()
            except Exception as exc:
                print(f"[watchdog] error in check: {exc}", file=sys.stderr)
            time.sleep(CHECK_INTERVAL)
    finally:
        PID_FILE.unlink(missing_ok=True)


def ensure_running() -> None:
    if PID_FILE.exists():
        pid = int(PID_FILE.read_text().strip())
        try:
            os.kill(pid, 0)
            print(f"[watchdog] already running (PID {pid})")
            return
        except ProcessLookupError:
            PID_FILE.unlink(missing_ok=True)
    subprocess.Popen(
        [sys.executable, __file__, "--daemon"],
        stdout=open("/tmp/session_watchdog.log", "a"),
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    print("[watchdog] started in background")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--ensure", action="store_true")
    parser.add_argument("--daemon", action="store_true")
    args = parser.parse_args()

    if args.check:
        check_once()
    elif args.ensure:
        ensure_running()
    elif args.daemon:
        run_daemon()
    else:
        parser.print_help()
```

---

## Running it

```sh
# Start the watchdog daemon (idempotent — safe to call on every session start)
python3 scripts/session_watchdog.py --ensure

# One-shot check (useful for testing)
python3 scripts/session_watchdog.py --check

# View daemon log
tail -f /tmp/session_watchdog.log
```

---

## Thresholds

| Event | Silence | Action |
|-------|---------|--------|
| First alert | 10 min | Telegram message to source topic |
| Repeat alert | 13 min | Second Telegram message, suggests /reset |
| Session closed | — | Alert state cleared, no more alerts |

These thresholds cover the typical case: a complex turn takes 5-8 min legitimately.
At 10 min it's unusual; at 13 min it's almost certainly hung.

---

## Integration with lisa-cron

Ensure the watchdog starts on agent restart:

```toml
[[jobs]]
name = "session-watchdog-ensure"
schedule = "@reboot"
command = "python3 /home/superlisa/workspace/scripts/session_watchdog.py --ensure"
timeout_secs = 10
```
