# Telegram stickers and custom emoji — generate and upload via agent

Your agent can generate images, convert them to Telegram-compatible formats,
and create sticker packs or custom emoji sets — using image generation tools
(DALL-E, Stable Diffusion, or any model) plus Pillow for resizing/conversion.

---

## Telegram format requirements

| Type | Format | Size | Notes |
|------|--------|------|-------|
| Static sticker | WEBP or PNG | 512x512 px, ≤512 KB | One side exactly 512px |
| Animated sticker | .tgs | ≤64 KB | Lottie JSON, gzipped |
| Video sticker | .webm (VP9) | 512x512, ≤256 KB, ≤3s | No audio track |
| Custom emoji | WEBP or PNG | 100x100 px | Telegram Premium or verified channel |

Static stickers are the easiest to generate — just resize and convert a PNG to WEBP.

---

## Step-by-step: static sticker

### 1. Generate the image

Ask your image model for a 512x512 image. If the model outputs at a different
size, Pillow handles the resize in the next step.

Example prompt for DALL-E or similar:
```
A cute cartoon fox face, flat design, transparent background, 512x512,
sticker style, thick outline, no text
```

Save the result to a file, e.g. `/tmp/sticker_raw.png`.

### 2. Resize and convert to WEBP

```python
from PIL import Image
import os

def prepare_sticker(input_path: str, output_path: str, size: int = 512) -> str:
    """
    Resize image to size x size (maintaining aspect ratio with padding),
    convert to WEBP. Returns output_path.
    """
    img = Image.open(input_path).convert("RGBA")

    # Resize so the longer side = size, then pad to square
    img.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = ((size - img.width) // 2, (size - img.height) // 2)
    canvas.paste(img, offset)

    canvas.save(output_path, "WEBP", quality=90)

    # Check file size
    file_size = os.path.getsize(output_path)
    if file_size > 512 * 1024:
        # Re-save with lower quality
        canvas.save(output_path, "WEBP", quality=70)

    return output_path

# Usage
prepare_sticker("/tmp/sticker_raw.png", "/tmp/sticker.webp")
```

### 3. Create a sticker pack via BotFather

Option A — via [@Stickers bot](https://t.me/Stickers) (manual, easiest):
1. Send `/newpack` to @Stickers.
2. Follow the prompts: pack name, first sticker file, emoji association.
3. Send `/publish` when done.

Option B — via Bot API (automated, for your agent to do it directly):

```python
import urllib.request
import json
import os

BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
USER_ID = int(os.environ["TELEGRAM_OWNER_USER_ID"])  # your Telegram user ID


def create_sticker_pack(name: str, title: str, sticker_path: str, emoji: str = "🦊") -> dict:
    """
    Create a new sticker set. Returns the Telegram API response.
    name: alphanumeric + underscore, ends with _by_<botname>
    title: display name of the pack (1-64 chars)
    """
    api_base = f"https://api.telegram.org/bot{BOT_TOKEN}"

    # Step 1: upload the sticker file, get file_id
    with open(sticker_path, "rb") as f:
        sticker_data = f.read()

    # Upload via sendDocument to get a file_id
    import io
    boundary = "----FormBoundary"
    body_parts = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n{USER_ID}",
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"png_sticker\"; filename=\"sticker.webp\"\r\nContent-Type: image/webp\r\n\r\n",
    ]
    # ... (use requests library or multipart form for cleaner upload)
    # Simplified: use the stickers API directly

    url = f"{api_base}/createNewStickerSet"
    # Full multipart upload — use requests for cleaner code:
    import subprocess
    result = subprocess.run([
        "curl", "-s", "-X", "POST", url,
        "-F", f"user_id={USER_ID}",
        "-F", f"name={name}",
        "-F", f"title={title}",
        "-F", f"png_sticker=@{sticker_path}",
        "-F", f"emojis={emoji}",
    ], capture_output=True, text=True)
    return json.loads(result.stdout)


# Example
resp = create_sticker_pack(
    name="my_fox_pack_by_mybot",
    title="Fox Stickers",
    sticker_path="/tmp/sticker.webp",
    emoji="🦊"
)
print(resp)
```

### 4. Add more stickers to the pack

```sh
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/addStickerToSet" \
  -F "user_id=${USER_ID}" \
  -F "name=my_fox_pack_by_mybot" \
  -F "png_sticker=@/tmp/sticker2.webp" \
  -F "emojis=😄"
```

---

## Custom emoji (100x100)

Custom emoji require **Telegram Premium** for personal use, or a **verified channel**
for channel emoji. The process is the same as stickers but at 100x100.

```python
def prepare_emoji(input_path: str, output_path: str) -> str:
    """Resize to 100x100 for custom emoji."""
    return prepare_sticker(input_path, output_path, size=100)
```

Use `createNewStickerSet` with `sticker_type=custom_emoji` in the API call.

---

## Animated stickers (.tgs)

`.tgs` is gzipped Lottie JSON. Creating them requires:
1. An animation as Lottie JSON (can be exported from After Effects, LottieFiles, or
   generated programmatically with the `lottie` Python library).
2. Gzip the JSON: `gzip -9 animation.json && mv animation.json.gz animation.tgs`

Constraints: ≤64 KB after gzip, no raster images inside the Lottie, 512x512 viewport.

---

## Video stickers (.webm)

Use ffmpeg to convert any short video to VP9 WEBM:

```sh
ffmpeg -i input.mp4 \
  -vf "scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2" \
  -c:v libvpx-vp9 -b:v 256k -an \
  -t 3 \
  output.webm
```

Flags:
- `-an` — no audio (required by Telegram)
- `-t 3` — max 3 seconds
- `-b:v 256k` — keeps file under 256 KB

---

## Notes

- Sticker pack names must be unique on Telegram and end with `_by_<botusername>`.
  If you get "name already taken", add a random suffix.
- The bot that creates the sticker pack is the pack owner. You can't transfer ownership.
- Images with real faces, copyrighted characters, or explicit content will be rejected
  by Telegram moderation when the pack is accessed publicly.
- Test the sticker in a private chat first before sharing the pack link.
