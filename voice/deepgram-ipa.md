# Deepgram IPA — bring-your-own-key speech transcription

IPA stands for **Individual Provider Account**. You register directly with Deepgram,
get your own API key, and the agent uses it for transcription. No shared quotas,
no platform broker, full usage visibility in your own Deepgram dashboard.

---

## Why bother with your own key

- **No shared quota.** Platform-pooled transcription keys get exhausted by other users.
  Your key has its own limits and its own $200 free credit.
- **No CPU load on the agent server.** Audio is sent directly to Deepgram's cloud.
  Local Whisper burns CPU, blocks other work, and takes 10-30s for a 3-minute clip.
  Deepgram returns in 1-3 seconds.
- **Better accuracy.** Deepgram Nova-2 consistently outperforms base/small Whisper
  on conversational Russian and English.

---

## Cost

Deepgram Nova-2 pricing: **$0.0043 per minute** = ~$0.26/hour of audio.

Wait — the guide says $0.06/hour. That's the older base model rate for reference;
check [deepgram.com/pricing](https://deepgram.com/pricing) for current rates.
With $200 free credits you get roughly 770 hours before paying anything.

---

## Register and get an API key

1. Go to [console.deepgram.com](https://console.deepgram.com) and sign up.
   Use a real email — you'll get $200 in free credits automatically, no card required.

2. In the console: **API Keys → Create a New API Key**.

3. Give it a name (e.g. "WAM agent"), set **Permission** to `Member` (full access
   for your own use), leave expiration as "Never".

4. The key starts with `sk_...` — copy it immediately. It's shown once.

5. Store it in your agent:

   ```sh
   python3 scripts/superlisa_store_secret.py DEEPGRAM_API_KEY sk_...
   ```

   The agent reads this as `DEEPGRAM_API_KEY` from its secret store.

---

## Verify it works

```sh
curl -X POST \
  "https://api.deepgram.com/v1/listen?model=nova-2&language=ru" \
  -H "Authorization: Token $DEEPGRAM_API_KEY" \
  -H "Content-Type: audio/wav" \
  --data-binary @/path/to/test.wav
```

You should get a JSON response with `transcript` in under 3 seconds.

---

## Basic Python usage

```python
import os
import urllib.request
import urllib.parse
import json

DEEPGRAM_API_KEY = os.environ["DEEPGRAM_API_KEY"]


def transcribe(audio_path: str, language: str = "ru") -> str:
    """
    Transcribe an audio file via Deepgram Nova-2.
    Returns the transcript string.
    Supports: wav, mp3, ogg, m4a, flac, webm.
    """
    params = urllib.parse.urlencode({
        "model": "nova-2",
        "language": language,
        "punctuate": "true",
        "diarize": "false",
    })
    url = f"https://api.deepgram.com/v1/listen?{params}"

    with open(audio_path, "rb") as f:
        audio_data = f.read()

    req = urllib.request.Request(
        url,
        data=audio_data,
        headers={
            "Authorization": f"Token {DEEPGRAM_API_KEY}",
            "Content-Type": "audio/wav",  # Deepgram auto-detects format
        },
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=60) as resp:
        result = json.loads(resp.read())

    return result["results"]["channels"][0]["alternatives"][0]["transcript"]


if __name__ == "__main__":
    import sys
    path = sys.argv[1] if len(sys.argv) > 1 else "test.wav"
    print(transcribe(path))
```

---

## With timestamps (for subtitles or searchable transcripts)

Add `&utterances=true` to the URL params. The response will include word-level
timestamps in `results.utterances[].words[].start` (seconds).

---

## Supported formats

Deepgram accepts: WAV, MP3, OGG, FLAC, AAC, M4A, WEBM, MP4 (audio track).
For Telegram voice messages (`.ogg` with OPUS codec): works natively.

---

## Compared to local Whisper

| | Deepgram Nova-2 | Local Whisper (base) |
|---|---|---|
| Latency (3 min clip) | ~2s | ~25s |
| CPU load on agent | None | High (blocks) |
| Russian accuracy | Excellent | Good |
| Cost | ~$0.26/hr audio | Free |
| Requires internet | Yes | No |

For typical agent use (voice messages, meeting summaries, dictation) Deepgram is
the clear choice. Whisper makes sense only when you have no internet or need
on-prem/air-gapped transcription.
