# Tailscale tunnel — agent in Docker, no root

Connect your WAM agent (running in a rootless Docker container) to your Tailnet.
No VPS, no open ports, no root on the host. The agent gets a stable Tailscale IP
and can reach any device on your network.

---

## Requirements

- Tailscale account at [tailscale.com](https://tailscale.com) (free tier is fine)
- Your computer (or any other device) already on the Tailnet
- Agent running in Docker without root privileges

---

## Step 1 — Install Tailscale on your computer

Download from [tailscale.com/download](https://tailscale.com/download).
Log in, verify your device appears in the [Tailscale admin console](https://login.tailscale.com/admin/machines).

---

## Step 2 — Create a reusable auth key

In the Tailscale admin console: **Settings → Keys → Generate auth key**.

Options:
- **Reusable:** yes (so it works across container restarts)
- **Ephemeral:** yes (the node auto-removes from the Tailnet when it goes offline — keeps your machine list clean)
- **Expiry:** set to whatever you want, or disable expiry

Copy the key (format: `tskey-auth-...`).

Store it in the agent's secret store:

```sh
python3 scripts/superlisa_store_secret.py TAILSCALE_AUTH_KEY tskey-auth-...
```

---

## Step 3 — Install tailscaled in userspace mode (no root)

Inside the agent workspace, run:

```sh
# Download the Tailscale static binary
curl -fsSL "https://pkgs.tailscale.com/stable/tailscale_latest_amd64.tgz" -o /tmp/ts.tgz
tar -C /tmp -xzf /tmp/ts.tgz
# The archive extracts to something like tailscale_1.xx.x_amd64/
TS_DIR=$(ls -d /tmp/tailscale_*_amd64 | head -1)
cp "$TS_DIR/tailscale" "$TS_DIR/tailscaled" ~/workspace/.bin/
```

Or use your package manager if the container has one and you have user-level install access.

---

## Step 4 — Start tailscaled in userspace networking mode

Userspace networking doesn't require TUN/TAP device access or root:

```sh
mkdir -p ~/workspace/.tailscale-state

~/workspace/.bin/tailscaled \
  --tun=userspace-networking \
  --state=~/workspace/.tailscale-state/tailscaled.state \
  --socket=/tmp/tailscaled.sock \
  --port=41641 \
  &
```

`--tun=userspace-networking` is the key flag — it runs entirely in user space,
no kernel modules, no `/dev/net/tun`.

---

## Step 5 — Connect to your Tailnet

```sh
~/workspace/.bin/tailscale \
  --socket=/tmp/tailscaled.sock \
  up \
  --auth-key="$TAILSCALE_AUTH_KEY" \
  --hostname="wam-agent" \
  --accept-routes
```

You should see:

```
Success.
```

---

## Step 6 — Verify

```sh
~/workspace/.bin/tailscale --socket=/tmp/tailscaled.sock status
```

Expected output: your agent node (`wam-agent`) and your other devices listed,
each with a `100.x.x.x` IP.

Ping test:

```sh
~/workspace/.bin/tailscale --socket=/tmp/tailscaled.sock ping your-computer-hostname
```

---

## Persisting state across restarts

The `--state` file (`~workspace/.tailscale-state/tailscaled.state`) stores the
node's identity. As long as this file exists and the auth key is reusable,
the agent reconnects without re-authenticating on restart.

Add the startup commands to your agent's init script or a lisa-cron `@reboot` job.

---

## SOCKS5 proxy for outbound traffic (optional)

Userspace mode doesn't route system traffic through Tailscale automatically —
you need to use the built-in SOCKS5 proxy for that:

```sh
~/workspace/.bin/tailscaled \
  --tun=userspace-networking \
  --socks5-server=localhost:1055 \
  --outbound-http-proxy-listen=localhost:1056 \
  ...
```

Then configure tools that need to reach Tailnet IPs:

```sh
export https_proxy=http://localhost:1056
export http_proxy=http://localhost:1056
```

---

## Troubleshooting

**"failed to connect to ... tailscaled.sock"** — tailscaled isn't running.
Check `ps aux | grep tailscaled`.

**Node appears offline in admin console** — ephemeral nodes vanish when tailscaled
stops. Restart tailscaled and `tailscale up` again with the same auth key.

**Can't reach Tailnet IPs** — in userspace mode you need the SOCKS5 proxy (see above)
or use `tailscale serve`/`funnel` for inbound rather than outbound routing.
