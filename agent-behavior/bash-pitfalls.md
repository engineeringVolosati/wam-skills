# Bash pitfalls for agents

Common mistakes that produce silent wrong output instead of an error.

---

## Heredoc with single quotes blocks variable expansion

```sh
# WRONG — $TEXT arrives literally as "$TEXT"
TEXT="hello world"
python3 -c "print('$TEXT')" <<'EOF'
$TEXT
EOF

# RIGHT — use double quotes on the heredoc delimiter
python3 -c "..." <<EOF
$TEXT
EOF
```

Single-quoted heredoc (`<<'EOF'`) treats everything inside as literal text.
`$VARIABLE` won't expand. Use unquoted `<<EOF` when you need variable substitution.

When building JSON task files with bash variables, use Python directly instead
of bash heredocs — it's safer and handles quoting correctly:

```python
# RIGHT — pure Python, no bash quoting issues
import json, pathlib

text = "the actual message text"
task = {"id": "...", "params": {"text": text, ...}}
pathlib.Path("queue/pending/task.json").write_text(
    json.dumps(task, ensure_ascii=False)
)
```

This pattern discovered in production when userbot tasks sent literal `$TEXT`
to recipients instead of the intended message. (2026-06-08)

---

## Sending to own user ID via Telethon goes to Saved Messages

```python
# WRONG for testing DM appearance — goes to Saved Messages, not a real DM
client.send_message(OWN_USER_ID, text)

# RIGHT — send to a group/topic to test how messages look to others
client.send_message(CHAT_ID, text, reply_to=THREAD_ID)
```

When Telethon's session owner sends to their own user ID, the message lands
in Saved Messages — a private channel only they can see. This is useless for
testing how a DM looks to a recipient.

To verify message appearance: send to a known group topic, not to self.
