# Karing and Throne — subscription setup

How to add your aggregated subscription URLs to Karing (iOS/macOS) and Throne (Android/Windows).

---

## Karing

**Platform:** iOS, macOS, Windows

### Add a subscription

1. Open Karing → tap the **+** button (bottom center on iOS, top-right on macOS).
2. Select **Subscribe** (not "Add manually").
3. Paste the raw `githubusercontent.com` URL of one of your subscription files:
   ```
   https://raw.githubusercontent.com/yourname/vpn-sub/main/subscriptions/BLACK_VLESS_RUS.txt
   ```
4. Give it a name (e.g. "WAM Desktop") and tap **Save**.
5. Repeat for mobile and Reality pools if you want separate profiles.

### Update interval

In Karing settings: **Subscription → Auto update** — set to 1 hour to match
the cron schedule.

### Basic routing

Karing uses rule-based routing. For most users the default "Proxy" mode works.
If you want Russian services to bypass the proxy:

1. Go to **Settings → Rules**.
2. Add a rule group with `GEOIP,RU,DIRECT` to route Russian IPs directly.
3. Keep `MATCH,PROXY` as the final fallback.

---

## Throne

**Platform:** Android, Windows

### Add a subscription

1. Open Throne → **Profiles** tab → tap **+** (top right).
2. Choose **Import from URL**.
3. Paste the raw URL:
   ```
   https://raw.githubusercontent.com/yourname/vpn-sub/main/subscriptions/BLACK_VLESS_RUS_mobile.txt
   ```
4. Name it and tap **Import**.

The mobile pool (`BLACK_VLESS_RUS_mobile.txt`) is optimized for mobile networks
with better keep-alive behavior. Use it for Throne on Android.

### Update interval

Throne: **Profile → Edit → Auto-update** → set to `3600` seconds (1 hour).

### Basic routing

Throne uses outbound profiles. For a simple setup:

- Default outbound: **proxy** (your VLESS config, selected automatically from the pool)
- Add a bypass rule for `geoip:ru` if you need local Russian services direct

---

## Notes

- The `githubusercontent.com` URL is plain HTTP text — no auth needed for public repos.
- After your `update.py` runs (every hour), both apps will pull fresh keys on their
  next scheduled update. No manual refresh needed.
- If a key stops working, the aggregator automatically pulls fresh upstream keys on the
  next run. Your personal key is always at position 0 in the list.
- Reality whitelist pool (`Vless-Reality-White-Lists-Rus-Mobile.txt`) is for clients that
  support VLESS Reality (xray-core). If your client doesn't support it, ignore that URL.
