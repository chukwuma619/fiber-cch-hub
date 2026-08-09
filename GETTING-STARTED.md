# Getting started

This guide walks you through running a **Fiber Cross-Chain Hub (CCH)** on your computer or a cloud server. No coding required — you copy commands into a terminal and edit one settings file.

**What you get:** three connected services that let you operate atomic swaps between CKB (Fiber) and Bitcoin (Lightning) on **testnet**.

| Service | What it does |
| --- | --- |
| **Fiber** | Your node on CKB / Fiber testnet (channels, invoices) |
| **LND** | Your Lightning node on Bitcoin testnet |
| **CCH** | The swap hub that connects Fiber and Lightning |

---

## Before you begin

### 1. Install Docker

Docker runs the hub in isolated containers so you do not install Fiber or LND manually.

- **Mac:** [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/) — download, install, open Docker Desktop, wait until it says **Running**.
- **Windows:** [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) — same idea; use WSL 2 if prompted.
- **Linux:** [Docker Engine](https://docs.docker.com/engine/install/) + [Compose plugin](https://docs.docker.com/compose/install/linux/).

**Check it works** — open **Terminal** (Mac/Linux) or **PowerShell** (Windows) and run:

```bash
docker --version
docker compose version
```

You should see version numbers, not “command not found”.

### 2. Install Git (to clone this repo)

- **Mac:** `xcode-select --install` or [git-scm.com](https://git-scm.com/downloads)
- **Windows:** [git-scm.com](https://git-scm.com/downloads)

### 3. Optional but helpful

- **jq** — used by setup scripts. Mac: `brew install jq`. Linux: `sudo apt install jq` (Debian/Ubuntu).

---

## Run locally (step by step)

### Step 1 — Clone the repository

Pick a folder (e.g. your Desktop), open Terminal, and run:

```bash
cd ~/Desktop
git clone <paste-the-repo-url-here>
cd fiber-cch-hub
```

Use the green **Code** button on GitHub to copy the URL.

### Step 2 — Create your settings file

```bash
cp .env.example .env
```

Open `.env` in any text editor (Notepad, TextEdit, VS Code). **Change these two lines** to passwords you choose and will remember:

```bash
FIBER_SECRET_KEY_PASSWORD=your-secret-here
LND_WALLET_PASSWORD=your-lnd-password-here
```

Do not share these passwords or commit `.env` to Git (it is already ignored).

### Step 3 — Start the hub

```bash
make up
```

The first run downloads Docker images (several GB) and can take **10–30 minutes** depending on your internet. Later starts are much faster.

When it finishes, you should see:

```text
Fiber RPC: http://127.0.0.1:8227
CCH RPC:   http://127.0.0.1:8327
```

### Step 4 — Check everything is running

```bash
make ps
```

All three services (`fiber`, `lnd`, `cch`) should show **Up**. Fiber should show **healthy**.

**Lightning sync:** LND must catch up to the Bitcoin testnet chain before payments work. This can take **30+ minutes**. Check progress:

```bash
docker exec fiber-cch-hub-lnd lncli --network=testnet getinfo
```

Look for `"synced_to_chain": true`. While it is `false`, the hub is starting but not ready for real Lightning payments yet.

### Step 5 — Stop the hub

```bash
make down
```

Your data stays in the `data/` folder so the next `make up` reuses wallets and node state.

---

## Useful commands

| Command | What it does |
| --- | --- |
| `make up` | Start (or restart) the full stack |
| `make down` | Stop all containers |
| `make ps` | Show which containers are running |
| `make logs` | Stream live logs (press `Ctrl+C` to exit) |
| `make doctor` | Check Docker and download Fiber image if missing |
| `make pull` | Update Docker images to latest pinned versions |

---

## Deploy on a server (VPS / cloud)

Use the same steps on a Linux server (DigitalOcean, AWS, Hetzner, etc.).

1. **SSH into the server** (your provider will give you `ssh user@ip-address`).
2. **Install Docker** (see links above for Linux).
3. **Clone the repo** and **edit `.env`** (same as local).
4. **Open firewall ports** if you need remote access:

   | Port | Service |
   | --- | --- |
   | 8228 | Fiber P2P (peers) |
   | 8227 | Fiber RPC (keep private in production) |
   | 8327 | CCH RPC (keep private in production) |
   | 9735 | Lightning P2P |
   | 10009 | LND RPC (keep private in production) |

   For a first testnet setup, you can leave RPC ports closed to the public and use SSH tunnels.

5. **Start in the background:**

   ```bash
   make up
   ```

   Containers use `restart: unless-stopped`, so they come back after a server reboot.

6. **Updates:** `git pull`, then `make pull`, then `make down && make up`.

**Security:** testnet is for learning. Before mainnet, put RPC behind a firewall or VPN, use strong passwords, and back up `data/` (especially `data/lnd` and `data/fiber`).

---

## Troubleshooting

### “Docker daemon is not running”

Open **Docker Desktop** (Mac/Windows) and wait until it is running, then try again.

### “Address already in use” or orphan container warnings

An old version of the stack may still be running:

```bash
make down
make up
```

If that fails, remove leftover data from an old layout and start fresh (this deletes local wallets):

```bash
make down
rm -rf data/lnd-ingrid data/lnd-bob data/bitcoind
make up
```

### “FAIL found regtest LND data”

You switched from an older regtest setup. Remove LND data and recreate the wallet:

```bash
make down
rm -rf data/lnd
make up
```

**Save your LND seed phrase** when the wallet is created — you need it to recover funds.

### CCH or Fiber won’t start

View logs:

```bash
docker compose logs cch --tail=50
docker compose logs fiber --tail=50
```

Common fix: re-copy configs and restart:

```bash
make bootstrap
make down
make up
```

### `make: command not found`

On Linux, install build tools: `sudo apt install make`. On Mac, install Xcode command line tools: `xcode-select --install`.

---

## After the hub is running

Starting the containers is only the first step. To **actually swap**, you still need:

1. **cWBTC on Fiber testnet** — [faucet](https://faucet-cwbtc.ckb.dev/) and [setup guide](https://faucet-cwbtc.ckb.dev/guide.html)
2. **Fiber channels** with liquidity
3. **Lightning channels** on testnet (once LND is synced)

See [ROADMAP.md](ROADMAP.md) for what is done and what is next.

---

## Where to learn more

- [README](../README.md) — overview, architecture, RPC reference
- [Fiber CCH API](https://www.fiber.world/docs/api-reference/cross-chain/cch)
- [Cross-Chain HTLC docs](https://www.fiber.world/docs/res/cross-chain-htlc#standalone-mode)
